import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient } from "../_shared/supabase-client.ts";
import { getPartnerToken, registerWebhook } from "../_shared/dupr-client.ts";
import { requireJsonContentType, sanitizeErrorForClient } from "../_shared/validation.ts";

/**
 * Admin-only function to register our webhook URL with DUPR.
 * Called once during setup (or to update the webhook URL).
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const ctError = requireJsonContentType(req);
  if (ctError) return ctError;

  try {
    const supabase = createUserClient(req);

    // Authenticate caller
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

    // Simple admin check: compare against ADMIN_USER_ID env var
    const adminUserId = Deno.env.get("ADMIN_USER_ID");
    if (adminUserId && user.id !== adminUserId) {
      return new Response(JSON.stringify({ error: "Admin access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { webhookUrl } = body;

    if (!webhookUrl) {
      return new Response(
        JSON.stringify({ error: "webhookUrl is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Generate partner token and register webhook
    const partner = await getPartnerToken();
    const result = await registerWebhook(partner.accessToken, webhookUrl);

    return new Response(
      JSON.stringify({ success: true, result }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: sanitizeErrorForClient(err, "dupr-register-webhook") }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
