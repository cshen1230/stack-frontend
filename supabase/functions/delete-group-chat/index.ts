import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient } from "../_shared/supabase-client.ts";

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

    const body = await req.json();
    const { group_chat_id } = body;

    if (!group_chat_id) {
      return new Response(
        JSON.stringify({ error: "group_chat_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Verify the requester is an admin
    const { data: membership, error: memberError } = await supabase
      .from("group_chat_members")
      .select("role")
      .eq("group_chat_id", group_chat_id)
      .eq("user_id", user.id)
      .single();

    if (memberError || !membership || membership.role !== "admin") {
      return new Response(
        JSON.stringify({ error: "Only admins can delete group chats" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Verify it's not session-linked
    const { data: chat, error: chatError } = await supabase
      .from("group_chats")
      .select("game_id")
      .eq("id", group_chat_id)
      .single();

    if (chatError) throw chatError;

    if (chat.game_id) {
      return new Response(
        JSON.stringify({ error: "Cannot delete a session-linked group chat" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Delete the group chat (cascades to members and messages)
    const { error: deleteError } = await supabase
      .from("group_chats")
      .delete()
      .eq("id", group_chat_id);

    if (deleteError) throw deleteError;

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
