import { corsHeaders } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-client.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createAdminClient();

    // Verify user from JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await admin.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { game_id } = body;

    if (!game_id) {
      return new Response(JSON.stringify({ error: "game_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch the game
    const { data: game, error: gameError } = await admin
      .from("games")
      .select("id, spots_available, spots_filled, is_cancelled, friends_only, creator_id")
      .eq("id", game_id)
      .single();

    if (gameError || !game) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (game.is_cancelled) {
      return new Response(JSON.stringify({ error: "This session has been cancelled" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check if session is full
    if (game.spots_filled >= game.spots_available) {
      return new Response(JSON.stringify({ error: "This session is full" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check if user is already a participant
    const { data: existing } = await admin
      .from("game_participants")
      .select("id")
      .eq("game_id", game_id)
      .eq("user_id", user.id)
      .eq("rsvp_status", "confirmed")
      .maybeSingle();

    if (existing) {
      return new Response(JSON.stringify({ error: "You are already in this session" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check friends_only: if set, verify the user is friends with the creator
    if (game.friends_only && game.creator_id !== user.id) {
      const { data: friendship } = await admin
        .from("friendships")
        .select("id")
        .or(
          `and(user_id.eq.${user.id},friend_id.eq.${game.creator_id}),and(user_id.eq.${game.creator_id},friend_id.eq.${user.id})`
        )
        .eq("status", "accepted")
        .maybeSingle();

      if (!friendship) {
        return new Response(
          JSON.stringify({ error: "This session is for friends only" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

    // Atomically increment spots_filled (only if still under limit)
    const { data: updated, error: updateError } = await admin
      .from("games")
      .update({ spots_filled: game.spots_filled + 1 })
      .eq("id", game_id)
      .lt("spots_filled", game.spots_available)
      .select("id")
      .maybeSingle();

    if (updateError) throw updateError;

    if (!updated) {
      return new Response(JSON.stringify({ error: "This session is full" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Insert participant
    const { error: participantError } = await admin
      .from("game_participants")
      .insert({
        game_id: game_id,
        user_id: user.id,
        rsvp_status: "confirmed",
      });

    if (participantError) {
      // Rollback spots_filled on failure
      await admin
        .from("games")
        .update({ spots_filled: game.spots_filled })
        .eq("id", game_id);
      throw participantError;
    }

    // Auto-add user to the session's linked group chat (if one exists)
    const { data: linkedChat } = await admin
      .from("group_chats")
      .select("id")
      .eq("game_id", game_id)
      .maybeSingle();

    if (linkedChat) {
      // Check if already a member (shouldn't be, but safe)
      const { data: existingMember } = await admin
        .from("group_chat_members")
        .select("id")
        .eq("group_chat_id", linkedChat.id)
        .eq("user_id", user.id)
        .maybeSingle();

      if (!existingMember) {
        await admin.from("group_chat_members").insert({
          group_chat_id: linkedChat.id,
          user_id: user.id,
          role: "member",
        });
      }
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
