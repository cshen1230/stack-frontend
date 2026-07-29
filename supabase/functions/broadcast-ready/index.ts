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

    // DELETE: clear active availability
    if (req.method === "DELETE") {
      const { error } = await supabase
        .from("available_players")
        .delete()
        .eq("user_id", user.id);

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // POST: set/update active availability
    const body = await req.json();
    const {
      available_from,
      available_until,
      latitude,
      longitude,
      preferred_format,
      note,
    } = body;

    if (!available_until) {
      return new Response(
        JSON.stringify({ error: "available_until is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Build upsert row
    const row: Record<string, unknown> = {
      user_id: user.id,
      status: "available",
      available_from: available_from || new Date().toISOString(),
      available_until,
    };

    if (latitude != null && longitude != null) {
      row.location = `SRID=4326;POINT(${longitude} ${latitude})`;
    }
    if (preferred_format) row.preferred_format = preferred_format;
    if (note) row.note = note;

    // Upsert: delete existing then insert (simpler than ON CONFLICT with geography)
    await supabase
      .from("available_players")
      .delete()
      .eq("user_id", user.id);

    const { error: insertError } = await supabase
      .from("available_players")
      .insert(row);

    if (insertError) throw insertError;

    // TODO: Query user_devices for friend device tokens and send APNs push notifications
    // This will be implemented when push notification infrastructure is ready.
    // Steps:
    // 1. Query friendships to get friend user IDs
    // 2. Query user_devices for those friend IDs
    // 3. Send APNs to each device token

    return new Response(
      JSON.stringify({ success: true }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
