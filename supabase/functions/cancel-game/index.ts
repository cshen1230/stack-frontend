import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient, createAdminClient } from "../_shared/supabase-client.ts";
import {
  TwilioSMSChannel,
  formatGameCancelledSMS,
  formatGameTime,
  type GameSummary,
} from "../_shared/sms-channel.ts";
import { requireJsonContentType, sanitizeErrorForClient } from "../_shared/validation.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const ctError = requireJsonContentType(req);
  if (ctError) return ctError;

  try {
    const supabase = createUserClient(req);

    // Verify the user is authenticated
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

    const { game_id } = await req.json();
    if (!game_id) {
      return new Response(
        JSON.stringify({ error: "game_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Fetch the game
    const { data: game, error: gameError } = await supabase
      .from("games")
      .select("*")
      .eq("id", game_id)
      .single();

    if (gameError || !game) {
      return new Response(
        JSON.stringify({ error: "Game not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Only the creator can cancel
    if (game.creator_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Only the game creator can cancel this game" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (game.is_cancelled) {
      return new Response(
        JSON.stringify({ error: "Game is already cancelled" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Cancel the game
    const { error: updateError } = await supabase
      .from("games")
      .update({ is_cancelled: true })
      .eq("id", game_id);

    if (updateError) throw updateError;

    // Cancel all confirmed/waitlisted RSVPs
    const { error: rsvpError } = await supabase
      .from("game_participants")
      .update({ rsvp_status: "cancelled" })
      .eq("game_id", game_id)
      .neq("rsvp_status", "cancelled");

    if (rsvpError) throw rsvpError;

    // ── Notify SMS invitees (best-effort) ───────────────
    try {
      const admin = createAdminClient();
      const { data: smsRows } = await admin
        .from("sms_invitations")
        .select("id, phone_number, rsvp_status")
        .eq("game_id", game_id)
        .in("rsvp_status", ["pending", "accepted"]);

      if (smsRows && smsRows.length > 0) {
        // Bulk-cancel all SMS invitations
        await admin
          .from("sms_invitations")
          .update({ rsvp_status: "cancelled" })
          .eq("game_id", game_id)
          .in("rsvp_status", ["pending", "accepted"]);

        // Send cancellation SMS to accepted invitees
        const gameSummary: GameSummary = {
          sessionName: game.session_name,
          creatorName: "",
          // The session's zone, not the edge runtime's — see formatGameTime.
          gameDatetime: formatGameTime(game.game_datetime, game.timezone),
          locationName: game.location_name,
          gameFormat: game.game_format,
          roster: [],
        };

        // Get creator name for the SMS
        const { data: creator } = await admin
          .from("users")
          .select("first_name, last_name")
          .eq("id", game.creator_id)
          .single();
        if (creator) {
          gameSummary.creatorName = `${creator.first_name} ${creator.last_name}`;
        }

        const twilio = new TwilioSMSChannel();
        const smsBody = formatGameCancelledSMS(gameSummary);
        const accepted = smsRows.filter((r) => r.rsvp_status === "accepted");
        for (const row of accepted) {
          try {
            await twilio.sendNotification(row.phone_number, smsBody);
          } catch {
            // Don't fail the cancel because of an SMS error
          }
        }
      }
    } catch {
      // SMS notification is best-effort — never block the cancel
    }

    return new Response(
      JSON.stringify({ success: true, message: "Game cancelled" }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: sanitizeErrorForClient(err, "cancel-game") }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
