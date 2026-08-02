/**
 * Inbound Twilio webhook — receives SMS replies and updates sms_invitations.
 * Deployed with --no-verify-jwt; security comes from Twilio signature validation.
 */

import { createAdminClient } from "../_shared/supabase-client.ts";
import {
  TwilioSMSChannel,
  normalizePhoneNumber,
  formatGameTime,
  formatAcceptedSMS,
  formatDeclinedSMS,
  formatCancelledSMS,
  formatGameCancelledSMS,
  formatGameFullSMS,
  formatExpiredSMS,
  formatAlreadyRepliedSMS,
  formatUnrecognizedSMS,
  formatNoInvitationFoundSMS,
  formatHelpSMS,
  formatOptOutSMS,
  type GameSummary,
} from "../_shared/sms-channel.ts";

const EMPTY_TWIML =
  '<?xml version="1.0" encoding="UTF-8"?><Response></Response>';

function twimlResponse(): Response {
  return new Response(EMPTY_TWIML, {
    status: 200,
    headers: { "Content-Type": "text/xml" },
  });
}

type Intent = "accept" | "decline" | "cancel" | "stop" | "start" | "help" | "unknown";

/** Parse the normalised reply intent. */
function parseReply(body: string): Intent {
  const upper = body.toUpperCase().trim();

  // Carrier-mandated keywords first — these outrank anything else the word could mean. STOP is
  // not a request to leave one session, it is a request to never hear from us again.
  if (["STOP", "STOPALL", "UNSUBSCRIBE", "END", "QUIT", "CANCELALL", "REVOKE"].includes(upper))
    return "stop";
  if (["START", "UNSTOP", "YES SUBSCRIBE", "RESUBSCRIBE"].includes(upper)) return "start";
  if (["HELP", "INFO"].includes(upper)) return "help";

  if (["Y", "YES", "YEP", "YEAH", "YA", "YUP", "JOIN"].includes(upper))
    return "accept";
  if (["N", "NO", "NOPE", "NAH", "PASS"].includes(upper)) return "decline";
  // "QUIT" belongs to the opt-out set above; leaving a session is CANCEL and its neighbours.
  if (["CANCEL", "LEAVE", "OUT", "DROP", "REMOVE"].includes(upper))
    return "cancel";
  return "unknown";
}

Deno.serve(async (req) => {
  // Only accept POST
  if (req.method !== "POST") return twimlResponse();

  const rawBody = await req.text();
  const twilio = new TwilioSMSChannel();

  // Validate Twilio signature
  const valid = await twilio.validateInbound(req, rawBody);
  if (!valid) {
    console.warn("Invalid Twilio signature");
    return new Response("Forbidden", { status: 403 });
  }

  const params = new URLSearchParams(rawBody);
  const msg = twilio.parseInbound(params);
  // An inbound `From` is already E.164 from Twilio; if it somehow isn't, keep the raw value
  // rather than dropping the message, since it still has to match what we stored.
  const phone = normalizePhoneNumber(msg.from) ?? msg.from;
  const intent = parseReply(msg.body);
  const admin = createAdminClient();

  /**
   * Every database call here is best-effort in the sense that failing one must not take down
   * the webhook — Twilio retries a non-2xx, so a crash means the same message arriving again
   * and again. Note this is a real try/catch: a Supabase query builder is a PromiseLike with a
   * `then` and no `catch`, so `.catch(() => {})` on one is a TypeError, not a safety net.
   */
  // deno-lint-ignore no-explicit-any
  async function quietly(work: PromiseLike<any>): Promise<any> {
    try {
      return await work;
    } catch (err) {
      console.error("webhook side-effect failed:", err);
      // Shaped like a Supabase response so every caller can destructure it the same way,
      // whether the query returned an error or threw one.
      return { data: null, error: err };
    }
  }

  // Log inbound
  await quietly(
    admin.from("sms_log").insert({
      direction: "inbound",
      phone_number: phone,
      message_body: msg.body,
      twilio_sid: msg.messageSid,
      status: "received",
    }),
  );

  /** Send a reply SMS (best-effort). */
  async function reply(text: string) {
    try {
      const sid = await twilio.sendNotification(phone, text);
      await quietly(
        admin.from("sms_log").insert({
          direction: "outbound",
          // Answers to something they sent us, so they never count against the cap on how
          // often a number can be cold-texted.
          kind: "reply",
          phone_number: phone,
          message_body: text,
          twilio_sid: sid,
          status: sid ? "sent" : "failed",
        }),
      );
    } catch (err) {
      console.error("webhook reply failed:", err);
    }
  }

  // ── Carrier keywords ──────────────────────────────────
  //
  // Handled before anything else and without touching a game: someone opting out is not making
  // an RSVP decision, and the only correct response is to stop.

  if (intent === "stop") {
    // Check if already opted out to avoid re-processing STOP and double-cancelling RSVPs.
    const { data: alreadyOptedOut } = await quietly(
      admin.from("sms_opt_outs").select("phone_number").eq("phone_number", phone).maybeSingle(),
    );

    if (alreadyOptedOut) {
      await reply(formatOptOutSMS());
      return twimlResponse();
    }

    await quietly(
      admin.from("sms_opt_outs").upsert(
        { phone_number: phone, source: "sms_reply", opted_out_at: new Date().toISOString() },
        { onConflict: "phone_number" },
      ),
    );

    // Withdraw their outstanding RSVPs too. Leaving someone counted in a session they can no
    // longer be contacted about strands the organiser as much as it does them.
    const { data: releasing } = await quietly(
      admin
        .from("sms_invitations")
        .update({ rsvp_status: "cancelled" })
        .eq("phone_number", phone)
        .in("rsvp_status", ["pending", "accepted"])
        .select("game_id, rsvp_status"),
    );

    for (const row of releasing ?? []) {
      // Only an accepted invitation was holding a seat.
      if (row.rsvp_status === "accepted") {
        await quietly(
          admin.rpc("decrement_spots_filled", { p_game_id: row.game_id }),
        );
      }
    }

    // Twilio's own opt-out handling usually answers and blocks before this runs. Sending here
    // is harmless when it does (the send is rejected) and correct when it doesn't.
    await reply(formatOptOutSMS());
    return twimlResponse();
  }

  if (intent === "start") {
    await quietly(admin.from("sms_opt_outs").delete().eq("phone_number", phone));
    await reply(formatHelpSMS());
    return twimlResponse();
  }

  if (intent === "help") {
    await reply(formatHelpSMS());
    return twimlResponse();
  }

  // Someone who has opted out should never get another message, including an explanation of
  // why their reply did nothing.
  const { data: optedOut } = await quietly(
    admin.from("sms_opt_outs").select("phone_number").eq("phone_number", phone).maybeSingle(),
  );

  if (optedOut) return twimlResponse();

  if (intent === "unknown") {
    await reply(formatUnrecognizedSMS());
    return twimlResponse();
  }

  // ── Find the relevant invitation ──────────────────────

  const wanted = intent === "cancel" ? "accepted" : "pending";

  const { data: invitation } = await quietly(
    admin
      .from("sms_invitations")
      .select("*")
      .eq("phone_number", phone)
      .eq("rsvp_status", wanted)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
  );

  if (!invitation) {
    // Check if they have any invitation at all to give a better message
    const { data: latest } = await quietly(
      admin
        .from("sms_invitations")
        .select("rsvp_status")
        .eq("phone_number", phone)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
    );

    if (latest) {
      await reply(formatAlreadyRepliedSMS(latest.rsvp_status as string));
    } else {
      await reply(formatNoInvitationFoundSMS());
    }
    return twimlResponse();
  }

  // ── Fetch the game ────────────────────────────────────

  const { data: game } = await quietly(
    admin
      .from("games")
      .select("*, users!games_creator_id_fkey(first_name, last_name)")
      .eq("id", invitation.game_id)
      .single(),
  );

  if (!game) {
    await reply(formatNoInvitationFoundSMS());
    return twimlResponse();
  }

  const creatorUser = game.users as { first_name: string; last_name: string };
  const gameSummary: GameSummary = {
    sessionName: game.session_name as string | null,
    creatorName: `${creatorUser.first_name} ${creatorUser.last_name}`,
    gameDatetime: formatGameTime(game.game_datetime, game.timezone),
    locationName: game.location_name as string | null,
    gameFormat: game.game_format as string,
    roster: [],
  };

  // Check game is still active
  if (game.is_cancelled) {
    await quietly(
      admin
        .from("sms_invitations")
        .update({ rsvp_status: "cancelled" })
        .eq("id", invitation.id),
    );
    await reply(formatGameCancelledSMS(gameSummary));
    return twimlResponse();
  }

  if (new Date(game.game_datetime) < new Date()) {
    await reply(formatExpiredSMS());
    return twimlResponse();
  }

  // ── Process intent ────────────────────────────────────

  if (intent === "accept") {
    if (game.spots_filled >= game.spots_available) {
      await reply(formatGameFullSMS());
      return twimlResponse();
    }

    // Claim the row, and only if it is still pending. `.select()` is what makes this a guard:
    // an update matching zero rows is not a PostgREST error, so without reading back what
    // changed, a second concurrent "Y" would sail past an error check that never fires and
    // take the seat a second time.
    const { data: claimed } = await quietly(
      admin
        .from("sms_invitations")
        .update({ rsvp_status: "accepted" })
        .eq("id", invitation.id)
        .eq("rsvp_status", "pending")
        .select("id")
        .maybeSingle(),
    );

    if (!claimed) {
      await reply(formatAlreadyRepliedSMS("accepted"));
      return twimlResponse();
    }

    const { error: rpcErr } = await quietly(
      admin.rpc("increment_spots_filled", { p_game_id: invitation.game_id }),
    );

    if (rpcErr) {
      // The last seat went while we were writing. Put the invitation back rather than leaving
      // someone told they are in a session that has no room for them.
      console.error("increment_spots_filled error:", rpcErr);
      await quietly(
        admin
          .from("sms_invitations")
          .update({ rsvp_status: "pending" })
          .eq("id", invitation.id),
      );
      await reply(formatGameFullSMS());
      return twimlResponse();
    }

    // Update sms_log with invitation_id
    await quietly(
      admin
        .from("sms_log")
        .update({ invitation_id: invitation.id })
        .eq("twilio_sid", msg.messageSid),
    );

    await reply(formatAcceptedSMS(gameSummary));
  } else if (intent === "decline") {
    await quietly(
      admin
        .from("sms_invitations")
        .update({ rsvp_status: "declined" })
        .eq("id", invitation.id)
        .eq("rsvp_status", "pending"),
    );

    await reply(formatDeclinedSMS());
  } else if (intent === "cancel") {
    const { data: released } = await quietly(
      admin
        .from("sms_invitations")
        .update({ rsvp_status: "cancelled" })
        .eq("id", invitation.id)
        .eq("rsvp_status", "accepted")
        .select("id")
        .maybeSingle(),
    );

    if (!released) {
      await reply(formatAlreadyRepliedSMS("cancelled"));
      return twimlResponse();
    }

    // Only give the seat back if this call is the one that took it away.
    const { error: rpcErr } = await quietly(
      admin.rpc("decrement_spots_filled", { p_game_id: invitation.game_id }),
    );
    if (rpcErr) console.error("decrement_spots_filled error:", rpcErr);

    await reply(formatCancelledSMS());
  }

  return twimlResponse();
});
