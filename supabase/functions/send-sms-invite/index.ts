import { corsHeaders } from "../_shared/cors.ts";
import {
  createUserClient,
  createAdminClient,
} from "../_shared/supabase-client.ts";
import {
  TwilioSMSChannel,
  normalizePhoneNumber,
  isReservedNumber,
  formatGameTime,
  formatInviteSMS,
  type GameSummary,
} from "../_shared/sms-channel.ts";
import { requireJsonContentType, sanitizeErrorForClient } from "../_shared/validation.ts";

/**
 * Sending caps.
 *
 * Every send costs money and lands on somebody's phone, and nothing about being a confirmed
 * participant makes an account trustworthy with either. The per-game uniqueness constraint
 * stops a number being texted twice about the same session, but says nothing about one account
 * creating twenty sessions and texting the same number about each — which is the shape an
 * abuser would actually use.
 *
 * These are deliberately far above what organising real pickleball looks like: a big session is
 * a dozen invitations, not fifty.
 */
const MAX_INVITES_PER_SENDER_PER_DAY = 20;
const MAX_INVITES_PER_SENDER_PER_HOUR = 5;
const MAX_INVITES_PER_RECIPIENT_PER_DAY = 3;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const ctError = requireJsonContentType(req);
  if (ctError) return ctError;

  try {
    const supabase = createUserClient(req);

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { game_id, invitee_name, phone_number } = await req.json();
    if (!game_id || !invitee_name || !phone_number) {
      return new Response(
        JSON.stringify({
          error: "game_id, invitee_name, and phone_number are required",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const normalized = normalizePhoneNumber(phone_number);
    if (!normalized) {
      return new Response(
        JSON.stringify({
          error: "That doesn't look like a valid phone number.",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (isReservedNumber(normalized)) {
      return new Response(
        JSON.stringify({ error: "That number cannot receive SMS invitations." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Fetch the game with creator profile
    const { data: game, error: gameError } = await supabase
      .from("games")
      .select("*, users!games_creator_id_fkey(username, first_name, last_name)")
      .eq("id", game_id)
      .single();

    if (gameError || !game) {
      return new Response(JSON.stringify({ error: "Game not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (game.is_cancelled) {
      return new Response(
        JSON.stringify({ error: "Game has been cancelled" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (new Date(game.game_datetime) < new Date()) {
      return new Response(
        JSON.stringify({ error: "Game has already started" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (game.spots_filled >= game.spots_available) {
      return new Response(JSON.stringify({ error: "Game is full" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify inviter is creator or confirmed participant
    const isCreator = game.creator_id === user.id;
    if (!isCreator) {
      const { data: participation } = await supabase
        .from("game_participants")
        .select("id")
        .eq("game_id", game_id)
        .eq("user_id", user.id)
        .eq("rsvp_status", "confirmed")
        .maybeSingle();

      if (!participation) {
        return new Response(
          JSON.stringify({
            error: "You must be a participant to invite others",
          }),
          {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
    }

    const admin = createAdminClient();

    // Never text a number that has opted out. Twilio would refuse the send anyway, but only
    // after we had billed ourselves for it and written a row that sits at "pending" forever
    // with nobody able to explain why.
    const { data: optedOut } = await admin
      .from("sms_opt_outs")
      .select("phone_number")
      .eq("phone_number", normalized)
      .maybeSingle();

    if (optedOut) {
      return new Response(
        JSON.stringify({
          error: "That number has opted out of text messages.",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    const { count: sentToday } = await admin
      .from("sms_invitations")
      .select("id", { count: "exact", head: true })
      .eq("invited_by", user.id)
      .gte("created_at", since);

    if ((sentToday ?? 0) >= MAX_INVITES_PER_SENDER_PER_DAY) {
      return new Response(
        JSON.stringify({
          error: "You've sent a lot of text invites today. Try again tomorrow.",
        }),
        {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const sinceHour = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { count: sentThisHour } = await admin
      .from("sms_invitations")
      .select("id", { count: "exact", head: true })
      .eq("invited_by", user.id)
      .gte("created_at", sinceHour);

    if ((sentThisHour ?? 0) >= MAX_INVITES_PER_SENDER_PER_HOUR) {
      return new Response(
        JSON.stringify({
          error: "You've sent several invites recently. Please wait a bit.",
        }),
        {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Counted from the send log rather than the invitations table, and across every sender.
    // An invitation row is reused when someone declines and is invited again, so counting rows
    // would miss exactly the loop worth catching; the log has one entry per message that
    // actually went out. And the person being texted experiences the total — they do not care
    // how many different accounts it came from.
    const { count: receivedToday } = await admin
      .from("sms_log")
      .select("id", { count: "exact", head: true })
      .eq("phone_number", normalized)
      .eq("direction", "outbound")
      .eq("kind", "invite")
      .gte("created_at", since);

    if ((receivedToday ?? 0) >= MAX_INVITES_PER_RECIPIENT_PER_DAY) {
      return new Response(
        JSON.stringify({
          error: "That number has already had several invites today.",
        }),
        {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Check for existing invitation
    const { data: existing } = await admin
      .from("sms_invitations")
      .select("id, rsvp_status")
      .eq("game_id", game_id)
      .eq("phone_number", normalized)
      .maybeSingle();

    if (existing) {
      if (existing.rsvp_status === "pending" || existing.rsvp_status === "accepted") {
        return new Response(
          JSON.stringify({ error: "This person has already been invited" }),
          {
            status: 409,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      // Re-invite after decline/cancel: reset to pending
      const { error: updateErr } = await admin
        .from("sms_invitations")
        .update({
          rsvp_status: "pending",
          invitee_name,
          invited_by: user.id,
          sms_sid: null,
        })
        .eq("id", existing.id);
      if (updateErr) throw updateErr;
    } else {
      const { error: insertErr } = await admin
        .from("sms_invitations")
        .insert({
          game_id,
          invited_by: user.id,
          invitee_name,
          phone_number: normalized,
        });
      if (insertErr) throw insertErr;
    }

    // Build roster for the SMS body (capped to avoid an unbounded query)
    const { data: participants } = await admin
      .from("game_participants")
      // Named relationship: game_participants also points at users through invited_by and
      // approved_by, so a bare `users(…)` is ambiguous and PostgREST refuses the whole query.
      .select("users!game_participants_user_id_fkey(first_name, last_name)")
      .eq("game_id", game_id)
      .eq("rsvp_status", "confirmed")
      .limit(50);

    const { data: smsAccepted } = await admin
      .from("sms_invitations")
      .select("invitee_name")
      .eq("game_id", game_id)
      .eq("rsvp_status", "accepted")
      .limit(50);

    const roster: string[] = [];
    for (const p of participants ?? []) {
      const u = p.users as { first_name: string; last_name: string };
      roster.push(`${u.first_name} ${u.last_name}`);
    }
    for (const s of smsAccepted ?? []) {
      roster.push(s.invitee_name);
    }

    // Get inviter's name
    const { data: inviterProfile } = await admin
      .from("users")
      .select("first_name, last_name")
      .eq("id", user.id)
      .single();

    const inviterName = inviterProfile
      ? `${inviterProfile.first_name} ${inviterProfile.last_name}`
      : "Someone";

    const creatorUser = game.users as { first_name: string; last_name: string } | null;
    const gameSummary: GameSummary = {
      sessionName: game.session_name,
      creatorName: creatorUser
        ? `${creatorUser.first_name} ${creatorUser.last_name}`
        : "The organizer",
      // In the session's own zone, not the edge runtime's. The runtime is UTC, which is how a
      // 6pm Pacific game used to go out as "01:00 AM" the following day.
      gameDatetime: formatGameTime(game.game_datetime, game.timezone),
      locationName: game.location_name,
      gameFormat: game.game_format,
      roster,
    };

    const smsBody = formatInviteSMS(inviterName, gameSummary);

    // Send SMS
    const twilio = new TwilioSMSChannel();
    const sid = await twilio.sendInvite(normalized, smsBody);

    // Update sms_sid on the invitation
    if (sid) {
      await admin
        .from("sms_invitations")
        .update({ sms_sid: sid })
        .eq("game_id", game_id)
        .eq("phone_number", normalized);
    }

    // Log the outbound SMS
    const invitationRow = existing ?? (
      await admin
        .from("sms_invitations")
        .select("id")
        .eq("game_id", game_id)
        .eq("phone_number", normalized)
        .single()
    ).data;

    await admin.from("sms_log").insert({
      invitation_id: invitationRow?.id ?? null,
      direction: "outbound",
      kind: "invite",
      phone_number: normalized,
      message_body: smsBody,
      twilio_sid: sid,
      status: sid ? "sent" : "failed",
    });

    return new Response(
      JSON.stringify({ success: true, message: "SMS invitation sent" }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: sanitizeErrorForClient(err, "send-sms-invite") }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
