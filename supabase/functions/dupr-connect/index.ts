import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient, createAdminClient } from "../_shared/supabase-client.ts";
import {
  getUserBasicInfo,
  getUserEntitlements,
  getPartnerToken,
  subscribeUserToWebhook,
} from "../_shared/dupr-client.ts";
import { requireJsonContentType, sanitizeErrorForClient } from "../_shared/validation.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const ctError = requireJsonContentType(req);
  if (ctError) return ctError;

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
    const { userToken, refreshToken, duprId } = body;

    if (!userToken || !refreshToken || !duprId) {
      return new Response(
        JSON.stringify({ error: "userToken, refreshToken, and duprId are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 2. Verify identity and get verified ratings from DUPR
    const duprInfo = await getUserBasicInfo(userToken);

    // 3. Check entitlements (must have at least BASIC_L1)
    const { entitlements } = await getUserEntitlements(userToken);

    if (!entitlements.includes("BASIC_L1")) {
      return new Response(
        JSON.stringify({
          error: "DUPR account does not have required entitlements (BASIC_L1)",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 4. Store tokens in dupr_tokens (admin client — table has no public RLS policies)
    const admin = createAdminClient();

    // Token expires in ~1 hour; store expiry for refresh logic
    const tokenExpiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();

    const { error: tokenError } = await admin
      .from("dupr_tokens")
      .upsert(
        {
          user_id: user.id,
          dupr_user_id: duprInfo.duprId,
          access_token: userToken,
          refresh_token: refreshToken,
          token_expires_at: tokenExpiresAt,
        },
        { onConflict: "user_id" },
      );

    if (tokenError) throw tokenError;

    // 5. Update user profile with verified DUPR data
    // Use doubles rating as primary (more common in pickleball); fall back to singles
    const primaryRating = duprInfo.doublesRating ?? duprInfo.singlesRating;

    const { error: updateError } = await admin
      .from("users")
      .update({
        dupr_verified: true,
        dupr_id: duprInfo.duprId,
        dupr_rating: primaryRating,
        dupr_singles_rating: duprInfo.singlesRating,
        dupr_doubles_rating: duprInfo.doublesRating,
        dupr_entitlements: entitlements,
        dupr_entitlements_cached_at: new Date().toISOString(),
      })
      .eq("id", user.id);

    if (updateError) throw updateError;

    // 6. Subscribe user to RATING webhook events
    try {
      const partner = await getPartnerToken();
      await subscribeUserToWebhook(partner.accessToken, [duprInfo.duprId]);
    } catch (webhookErr) {
      // Non-fatal: log but don't fail the connection
      console.error("Failed to subscribe to DUPR webhook:", webhookErr);
    }

    // 7. Return verified profile data
    return new Response(
      JSON.stringify({
        success: true,
        profile: {
          dupr_id: duprInfo.duprId,
          dupr_verified: true,
          dupr_rating: primaryRating,
          dupr_singles_rating: duprInfo.singlesRating,
          dupr_doubles_rating: duprInfo.doublesRating,
          dupr_entitlements: entitlements,
          full_name: duprInfo.fullName,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: sanitizeErrorForClient(err, "dupr-connect") }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
