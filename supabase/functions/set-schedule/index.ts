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

    // DELETE: clear all schedule windows
    if (req.method === "DELETE") {
      const { error } = await supabase
        .from("user_schedules")
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

    // POST: full-replace schedule windows
    let body;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    const { windows } = body;

    if (!Array.isArray(windows)) {
      return new Response(
        JSON.stringify({ error: "windows must be an array" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Validate each window
    for (const w of windows) {
      if (
        w.day_of_week == null ||
        w.day_of_week < 0 ||
        w.day_of_week > 6
      ) {
        return new Response(
          JSON.stringify({
            error: "day_of_week must be between 0 (Sunday) and 6 (Saturday)",
          }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      if (!w.start_time || !w.end_time) {
        return new Response(
          JSON.stringify({ error: "start_time and end_time are required" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
    }

    // Delete existing windows, then insert new set
    const { error: deleteError } = await supabase
      .from("user_schedules")
      .delete()
      .eq("user_id", user.id);

    if (deleteError) throw deleteError;

    if (windows.length > 0) {
      const rows = windows.map((w: Record<string, unknown>) => ({
        user_id: user.id,
        day_of_week: w.day_of_week,
        start_time: w.start_time,
        end_time: w.end_time,
        preferred_format: w.preferred_format || null,
      }));

      const { error: insertError } = await supabase
        .from("user_schedules")
        .insert(rows);

      if (insertError) throw insertError;
    }

    return new Response(
      JSON.stringify({ success: true }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: sanitizeErrorForClient(err, "set-schedule") }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
