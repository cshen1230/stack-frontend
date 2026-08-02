import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient } from "../_shared/supabase-client.ts";
import { requireJsonContentType, sanitizeErrorForClient } from "../_shared/validation.ts";

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

    const { friendship_id, action } = await req.json();
    if (!friendship_id || !action) {
      return new Response(
        JSON.stringify({ error: "friendship_id and action are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (action !== "accept" && action !== "decline") {
      return new Response(
        JSON.stringify({ error: "action must be 'accept' or 'decline'" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Fetch the friendship — RLS ensures only parties can see it
    const { data: friendship, error: fetchError } = await supabase
      .from("friendships")
      .select("id, user_id, friend_id, status")
      .eq("id", friendship_id)
      .single();

    if (fetchError || !friendship) {
      return new Response(
        JSON.stringify({ error: "Friend request not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Only the recipient can respond
    if (friendship.friend_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Only the recipient can respond to a friend request" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (friendship.status !== "pending") {
      return new Response(
        JSON.stringify({ error: "This request is no longer pending" }),
        {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const newStatus = action === "accept" ? "accepted" : "declined";

    const { error: updateError } = await supabase
      .from("friendships")
      .update({ status: newStatus })
      .eq("id", friendship_id)
      .eq("status", "pending");

    if (updateError) throw updateError;

    return new Response(
      JSON.stringify({
        success: true,
        message: `Friend request ${newStatus}`,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: sanitizeErrorForClient(err, "respond-friend-request") }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
