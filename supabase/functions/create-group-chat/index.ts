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
    const { name, member_ids } = body;

    if (!name || typeof name !== "string" || name.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "name is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!member_ids || !Array.isArray(member_ids) || member_ids.length === 0) {
      return new Response(
        JSON.stringify({ error: "At least one member_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Create the group chat
    const { data: groupChat, error: chatError } = await supabase
      .from("group_chats")
      .insert({ name: name.trim(), created_by: user.id })
      .select()
      .single();

    if (chatError) throw chatError;

    // Add creator as admin
    const members = [
      { group_chat_id: groupChat.id, user_id: user.id, role: "admin" },
    ];

    // Add other members
    for (const memberId of member_ids) {
      if (memberId !== user.id) {
        members.push({
          group_chat_id: groupChat.id,
          user_id: memberId,
          role: "member",
        });
      }
    }

    const { error: membersError } = await supabase
      .from("group_chat_members")
      .insert(members);

    if (membersError) throw membersError;

    return new Response(
      JSON.stringify({ success: true, group_chat_id: groupChat.id }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
