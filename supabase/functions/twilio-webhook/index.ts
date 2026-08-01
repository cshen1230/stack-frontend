/**
 * Inbound Twilio webhook — receives SMS replies and updates sms_invitations.
 * Deployed with --no-verify-jwt; security comes from Twilio signature validation.
 */

import { createAdminClient } from "../_shared/supabase-client.ts";
import {
  TwilioSMSChannel,
  normalizePhoneNumber,
  formatAcceptedSMS,
  formatDeclinedSMS,
  formatCancelledSMS,
  formatGameCancelledSMS,
  formatGameFullSMS,
  formatExpiredSMS,
  formatAlreadyRepliedSMS,
  formatUnrecognizedSMS,
  formatNoInvitationFoundSMS,
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

/** Parse the normalised reply intent. */
function parseReply(
  body: string,
): "accept" | "decline" | "cancel" | "unknown" {
  const upper = body.toUpperCase().trim();
  if (["Y", "YES", "YEP", "YEAH", "YA", "YUP", "JOIN"].includes(upper))
    return "accept";
  if (["N", "NO", "NOPE", "NAH", "PASS"].includes(upper)) return "decline";
  if (["CANCEL", "LEAVE", "OUT", "DROP", "QUIT", "REMOVE"].includes(upper))
    return "cancel";
  return "unknown";
}

function buildGameSummary(game: Record<string, unknown>): GameSummary {
  const dt = new Date(game.game_datetime as string);
  return {
    sessionName: game.session_name as string | null,
    creatorName: "", // filled below if we have user join
    gameDatetime: dt.toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    }),
    locationName: game.location_name as string | null,
    gameFormat: game.game_format as string,
    roster: [],
  };
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
  const phone = normalizePhoneNumber(msg.from);
  const intent = parseReply(msg.body);
  const admin = createAdminClient();

  // Log inbound
  await admin.from("sms_log").insert({
    direction: "inbound",
    phone_number: phone,
    message_body: msg.body,
    twilio_sid: msg.messageSid,
    status: "received",
  }).catch(() => {}); // best-effort log

  /** Send a reply SMS (best-effort). */
  async function reply(text: string) {
    try {
      const sid = await twilio.sendInvite(phone, text);
      await admin.from("sms_log").insert({
        direction: "outbound",
        phone_number: phone,
        message_body: text,
        twilio_sid: sid,
        status: sid ? "sent" : "failed",
      });
    } catch { /* don't fail the webhook */ }
  }

  if (intent === "unknown") {
    await reply(formatUnrecognizedSMS());
    return twimlResponse();
  }

  // ── Find the relevant invitation ──────────────────────

  let invitation: Record<string, unknown> | null = null;

  if (intent === "accept" || intent === "decline") {
    // Most recent pending invitation for this phone
    const { data } = await admin
      .from("sms_invitations")
      .select("*")
      .eq("phone_number", phone)
      .eq("rsvp_status", "pending")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    invitation = data;
  } else if (intent === "cancel") {
    // Most recent accepted invitation
    const { data } = await admin
      .from("sms_invitations")
      .select("*")
      .eq("phone_number", phone)
      .eq("rsvp_status", "accepted")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    invitation = data;
  }

  if (!invitation) {
    // Check if they have any invitation at all to give a better message
    const { data: any } = await admin
      .from("sms_invitations")
      .select("rsvp_status")
      .eq("phone_number", phone)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (any) {
      await reply(formatAlreadyRepliedSMS(any.rsvp_status as string));
    } else {
      await reply(formatNoInvitationFoundSMS());
    }
    return twimlResponse();
  }

  // ── Fetch the game ────────────────────────────────────

  const { data: game } = await admin
    .from("games")
    .select("*, users!games_creator_id_fkey(first_name, last_name)")
    .eq("id", invitation.game_id)
    .single();

  if (!game) {
    await reply(formatNoInvitationFoundSMS());
    return twimlResponse();
  }

  const creatorUser = game.users as { first_name: string; last_name: string };
  const gameSummary = buildGameSummary(game);
  gameSummary.creatorName = `${creatorUser.first_name} ${creatorUser.last_name}`;

  // Check game is still active
  if (game.is_cancelled) {
    await admin
      .from("sms_invitations")
      .update({ rsvp_status: "cancelled" })
      .eq("id", invitation.id);
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

    const { error: updateErr } = await admin
      .from("sms_invitations")
      .update({ rsvp_status: "accepted" })
      .eq("id", invitation.id)
      .eq("rsvp_status", "pending"); // atomic guard

    if (updateErr) {
      console.error("SMS accept update error:", updateErr);
      await reply(formatAlreadyRepliedSMS("accepted"));
      return twimlResponse();
    }

    // Increment spots_filled
    const { error: rpcErr } = await admin.rpc("increment_spots_filled", {
      p_game_id: invitation.game_id,
    });
    if (rpcErr) console.error("increment_spots_filled error:", rpcErr);

    // Update sms_log with invitation_id
    await admin
      .from("sms_log")
      .update({ invitation_id: invitation.id })
      .eq("twilio_sid", msg.messageSid)
      .catch(() => {});

    await reply(formatAcceptedSMS(gameSummary));
  } else if (intent === "decline") {
    await admin
      .from("sms_invitations")
      .update({ rsvp_status: "declined" })
      .eq("id", invitation.id);

    await reply(formatDeclinedSMS());
  } else if (intent === "cancel") {
    const { error: updateErr } = await admin
      .from("sms_invitations")
      .update({ rsvp_status: "cancelled" })
      .eq("id", invitation.id)
      .eq("rsvp_status", "accepted"); // atomic guard

    if (updateErr) {
      console.error("SMS cancel update error:", updateErr);
      await reply(formatAlreadyRepliedSMS("cancelled"));
      return twimlResponse();
    }

    // Decrement spots_filled
    const { error: rpcErr } = await admin.rpc("decrement_spots_filled", {
      p_game_id: invitation.game_id,
    });
    if (rpcErr) console.error("decrement_spots_filled error:", rpcErr);

    await reply(formatCancelledSMS());
  }

  return twimlResponse();
});
