import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient, createAdminClient } from "../_shared/supabase-client.ts";
import { refreshUserToken } from "../_shared/dupr-client.ts";

/**
 * Refreshes an expired DUPR user access token.
 * Called by the iOS app when it detects the DUPR token is expired.
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

    // 2. Fetch user's refresh token from dupr_tokens (admin client — no public RLS)
    const admin = createAdminClient();

    const { data: tokenRow, error: fetchError } = await admin
      .from("dupr_tokens")
      .select("refresh_token")
      .eq("user_id", user.id)
      .single();

    if (fetchError || !tokenRow) {
      return new Response(
        JSON.stringify({ error: "No DUPR connection found. Please connect DUPR first." }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 3. Call DUPR refresh endpoint
    const refreshed = await refreshUserToken(tokenRow.refresh_token);

    // 4. Update dupr_tokens with new tokens and expiry
    const tokenExpiresAt = new Date(
      Date.now() + (refreshed.expiresIn ?? 3600) * 1000,
    ).toISOString();

    const { error: updateError } = await admin
      .from("dupr_tokens")
      .update({
        access_token: refreshed.accessToken,
        refresh_token: refreshed.refreshToken,
        token_expires_at: tokenExpiresAt,
      })
      .eq("user_id", user.id);

    if (updateError) throw updateError;

    // 5. Return new expiry time
    return new Response(
      JSON.stringify({
        success: true,
        token_expires_at: tokenExpiresAt,
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
