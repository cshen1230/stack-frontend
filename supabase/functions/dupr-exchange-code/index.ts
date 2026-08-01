import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient } from "../_shared/supabase-client.ts";
import { getPartnerApiBase } from "../_shared/dupr-client.ts";

/**
 * Exchanges a DUPR OAuth authorization code for user tokens.
 *
 * This keeps the client_secret server-side — the iOS app only sends
 * the authorization code it received from the OAuth redirect.
 *
 * Request body: { authorization_code: string }
 * Response: { userToken, refreshToken, duprId }
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createUserClient(req);

    // 1. Authenticate Supabase user
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
    const { authorization_code } = body;

    if (!authorization_code) {
      return new Response(
        JSON.stringify({ error: "authorization_code is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 2. Exchange authorization code for DUPR tokens
    const clientId = Deno.env.get("DUPR_CLIENT_ID")!;
    const clientSecret = Deno.env.get("DUPR_CLIENT_SECRET")!;
    const redirectUri = "stackpickleball://dupr/callback";

    const tokenRes = await fetch(`${getPartnerApiBase()}/auth/v1.0/token`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        grant_type: "authorization_code",
        client_id: clientId,
        client_secret: clientSecret,
        code: authorization_code,
        redirect_uri: redirectUri,
      }),
    });

    if (!tokenRes.ok) {
      const text = await tokenRes.text();
      return new Response(
        JSON.stringify({ error: `DUPR token exchange failed: ${text}` }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const tokenData = await tokenRes.json();
    const result = tokenData.result ?? tokenData;

    const userToken = result.access_token ?? result.accessToken ?? result.token;
    const refreshToken = result.refresh_token ?? result.refreshToken;
    const duprId = result.dupr_id ?? result.duprId ?? result.user_id ?? result.userId;

    if (!userToken || !refreshToken) {
      return new Response(
        JSON.stringify({ error: "DUPR token exchange returned incomplete data" }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({
        userToken,
        refreshToken,
        duprId: duprId ? String(duprId) : "",
      }),
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
