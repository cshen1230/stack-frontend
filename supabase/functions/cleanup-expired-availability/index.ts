import { corsHeaders } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-client.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // This is a cron/admin-only endpoint. Require either the cron secret or a
  // valid service-role bearer token. Without this check, anyone who knows the
  // URL can trigger a cleanup.
  const cronSecret = Deno.env.get("CRON_SECRET");
  const authHeader = req.headers.get("authorization") ?? "";
  const bearerToken = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : "";
  const incomingCronSecret = req.headers.get("x-cron-secret") ?? "";

  const isAuthorized =
    (cronSecret && incomingCronSecret === cronSecret) ||
    (bearerToken === Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));

  if (!isAuthorized) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabase = createAdminClient();

    // Call the database function that deletes expired entries
    const { data, error } = await supabase.rpc("cleanup_expired_availability");

    if (error) throw error;

    return new Response(
      JSON.stringify({
        success: true,
        deleted_count: data,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("cleanup-expired-availability error:", err);
    return new Response(
      JSON.stringify({ error: "An internal error occurred." }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
