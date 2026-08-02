import { corsHeaders } from "../_shared/cors.ts";
import { createAdminClient } from "../_shared/supabase-client.ts";
import {
  getPartnerApiBase,
  getUserBasicInfo,
  getUserEntitlements,
  getPartnerToken,
  subscribeUserToWebhook,
} from "../_shared/dupr-client.ts";
import { requireJsonContentType, sanitizeErrorForClient } from "../_shared/validation.ts";
import { rateLimit, clientIp } from "../_shared/rate-limit.ts";

/**
 * "Login with DUPR" — the primary auth endpoint.
 *
 * No prior Supabase session required (this IS the login).
 *
 * Flow:
 * 1. Exchange DUPR authorization_code for DUPR tokens
 * 2. Fetch user info + verify entitlements from DUPR
 * 3. Find or create a Supabase auth user (synthetic email + HMAC password)
 * 4. Sign in to get a Supabase session
 * 5. Store DUPR tokens
 * 6. Return session + DUPR info + is_new_user flag
 *
 * Request body: { authorization_code: string }
 * Response: { session, dupr_info, is_new_user }
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const ctError = requireJsonContentType(req);
  if (ctError) return ctError;

  // Rate-limit auth attempts by IP to slow credential-stuffing.
  if (!rateLimit(clientIp(req))) {
    return new Response(
      JSON.stringify({ error: "Too many attempts. Please wait a moment." }),
      {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  try {
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

    // ---------------------------------------------------------------
    // 1. Exchange authorization code for DUPR tokens
    // ---------------------------------------------------------------
    const clientId = Deno.env.get("DUPR_CLIENT_ID")!;
    const clientSecret = Deno.env.get("DUPR_CLIENT_SECRET")!;
    const redirectUri = Deno.env.get("DUPR_REDIRECT_URI") ?? "stackpickleball://dupr/callback";

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
      console.error("DUPR token exchange failed:", tokenRes.status, text);
      return new Response(
        JSON.stringify({ error: "DUPR token exchange failed" }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const tokenData = await tokenRes.json();
    const tokenResult = tokenData.result ?? tokenData;

    const userToken =
      tokenResult.access_token ?? tokenResult.accessToken ?? tokenResult.token;
    const refreshToken =
      tokenResult.refresh_token ?? tokenResult.refreshToken;
    const duprId = String(
      tokenResult.dupr_id ?? tokenResult.duprId ?? tokenResult.user_id ?? tokenResult.userId ?? "",
    );

    if (!userToken || !refreshToken) {
      return new Response(
        JSON.stringify({ error: "DUPR token exchange returned incomplete data" }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!duprId) {
      return new Response(
        JSON.stringify({ error: "DUPR token exchange did not return a user ID" }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ---------------------------------------------------------------
    // 2. Get user info from DUPR
    // ---------------------------------------------------------------
    const duprInfo = await getUserBasicInfo(userToken);

    // ---------------------------------------------------------------
    // 3. Verify entitlements (must have BASIC_L1)
    // ---------------------------------------------------------------
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

    // ---------------------------------------------------------------
    // 4. Find or create Supabase auth user
    // ---------------------------------------------------------------
    const admin = createAdminClient();

    // Derive a synthetic email and server-side password so the client
    // never needs to know or store credentials.
    const syntheticEmail = `${duprInfo.duprId}@dupr.stackpickleball.app`;
    const authSecretKey = Deno.env.get("AUTH_SECRET_KEY")!;
    const syntheticPassword = await hmacSha256(duprInfo.duprId, authSecretKey);

    const primaryRating = duprInfo.doublesRating ?? duprInfo.singlesRating;

    const userMetadata = {
      dupr_id: duprInfo.duprId,
      first_name: duprInfo.firstName,
      last_name: duprInfo.lastName,
      full_name: duprInfo.fullName,
      dupr_rating: primaryRating,
      dupr_singles_rating: duprInfo.singlesRating,
      dupr_doubles_rating: duprInfo.doublesRating,
      dupr_entitlements: entitlements,
    };

    // Try signing in first (returning user)
    let session;
    let isNewUser = false;

    const { data: signInData, error: signInError } =
      await admin.auth.signInWithPassword({
        email: syntheticEmail,
        password: syntheticPassword,
      });

    if (signInError) {
      // User doesn't exist — create them
      const { data: createData, error: createError } =
        await admin.auth.admin.createUser({
          email: syntheticEmail,
          password: syntheticPassword,
          email_confirm: true,
          user_metadata: userMetadata,
        });

      if (createError) {
        throw new Error(`Failed to create auth user: ${createError.message}`);
      }

      if (!createData.user) {
        throw new Error("User creation returned no user");
      }

      // Now sign in to get a session
      const { data: newSignIn, error: newSignInError } =
        await admin.auth.signInWithPassword({
          email: syntheticEmail,
          password: syntheticPassword,
        });

      if (newSignInError || !newSignIn.session) {
        throw new Error(
          `Failed to sign in new user: ${newSignInError?.message ?? "no session returned"}`,
        );
      }

      session = newSignIn.session;
      isNewUser = true;
    } else {
      session = signInData.session;

      // Update user_metadata with latest DUPR data
      if (session?.user) {
        await admin.auth.admin.updateUserById(session.user.id, {
          user_metadata: userMetadata,
        });
      }
    }

    if (!session) {
      throw new Error("No session obtained");
    }

    // ---------------------------------------------------------------
    // 5. Store DUPR tokens (admin — table has no public RLS policies)
    // ---------------------------------------------------------------
    const tokenExpiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();

    const { error: tokenStoreError } = await admin
      .from("dupr_tokens")
      .upsert(
        {
          user_id: session.user.id,
          dupr_user_id: duprInfo.duprId,
          access_token: userToken,
          refresh_token: refreshToken,
          token_expires_at: tokenExpiresAt,
        },
        { onConflict: "user_id" },
      );

    if (tokenStoreError) throw tokenStoreError;

    // ---------------------------------------------------------------
    // 6. If returning user, update public.users with latest DUPR data
    // ---------------------------------------------------------------
    if (!isNewUser) {
      const { data: existingProfile } = await admin
        .from("users")
        .select("id")
        .eq("id", session.user.id)
        .maybeSingle();

      if (existingProfile) {
        await admin
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
          .eq("id", session.user.id);
      }
    }

    // Check if public.users profile exists (determines is_new_user for client)
    const { data: profileRow } = await admin
      .from("users")
      .select("id")
      .eq("id", session.user.id)
      .maybeSingle();

    const profileExists = !!profileRow;

    // ---------------------------------------------------------------
    // 7. Subscribe to DUPR webhook (non-fatal)
    // ---------------------------------------------------------------
    try {
      const partner = await getPartnerToken();
      await subscribeUserToWebhook(partner.accessToken, [duprInfo.duprId]);
    } catch (webhookErr) {
      console.error("Failed to subscribe to DUPR webhook:", webhookErr);
    }

    // ---------------------------------------------------------------
    // 8. Return session + DUPR info
    // ---------------------------------------------------------------
    return new Response(
      JSON.stringify({
        session: {
          access_token: session.access_token,
          refresh_token: session.refresh_token,
          expires_in: session.expires_in,
          token_type: session.token_type,
          user: session.user,
        },
        dupr_info: {
          dupr_id: duprInfo.duprId,
          full_name: duprInfo.fullName,
          first_name: duprInfo.firstName,
          last_name: duprInfo.lastName,
          dupr_rating: primaryRating,
          dupr_singles_rating: duprInfo.singlesRating,
          dupr_doubles_rating: duprInfo.doublesRating,
          dupr_entitlements: entitlements,
        },
        is_new_user: !profileExists,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: sanitizeErrorForClient(err, "auth-with-dupr") }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Compute HMAC-SHA256(data, key) and return the hex digest.
 * Used to derive a deterministic server-side password from the DUPR ID.
 */
async function hmacSha256(data: string, key: string): Promise<string> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(data));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
