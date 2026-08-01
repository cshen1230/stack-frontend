import { corsHeaders } from "../_shared/cors.ts";
import {
  createUserClient,
  createAdminClient,
} from "../_shared/supabase-client.ts";
import {
  TwilioSMSChannel,
  normalizePhoneNumber,
  formatInviteSMS,
  type GameSummary,
} from "../_shared/sms-channel.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

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

    // Build roster for the SMS body
    const { data: participants } = await admin
      .from("game_participants")
      .select("users(first_name, last_name)")
      .eq("game_id", game_id)
      .eq("rsvp_status", "confirmed");

    const { data: smsAccepted } = await admin
      .from("sms_invitations")
      .select("invitee_name")
      .eq("game_id", game_id)
      .eq("rsvp_status", "accepted");

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

    const creatorUser = game.users as { first_name: string; last_name: string };
    const dt = new Date(game.game_datetime);
    const gameSummary: GameSummary = {
      sessionName: game.session_name,
      creatorName: `${creatorUser.first_name} ${creatorUser.last_name}`,
      gameDatetime: dt.toLocaleDateString("en-US", {
        weekday: "short",
        month: "short",
        day: "numeric",
        hour: "numeric",
        minute: "2-digit",
      }),
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
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
