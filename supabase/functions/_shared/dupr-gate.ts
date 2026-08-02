import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createAdminClient } from "./supabase-client.ts";
import { getUserEntitlements, refreshUserToken } from "./dupr-client.ts";

const ENTITLEMENTS_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

/**
 * Throws if the user has not completed DUPR verification.
 * Use in edge functions that require a verified DUPR account
 * (create-game, rsvp-to-game, set-availability, create-post, invite-to-game).
 *
 * Also re-checks entitlements if they are stale (>7 days old). If the user
 * has lost BASIC_L1, verification is revoked. Network errors during the
 * refresh are logged but do not block the user — the webhook will catch
 * rating/entitlement changes eventually.
 */
export async function requireDuprVerified(
  supabase: SupabaseClient,
  userId: string,
): Promise<void> {
  const { data: user, error } = await supabase
    .from("users")
    .select("dupr_verified, dupr_entitlements_cached_at")
    .eq("id", userId)
    .single();

  if (error || !user) {
    throw new DuprGateError("User profile not found");
  }

  if (!user.dupr_verified) {
    throw new DuprGateError("DUPR verification required");
  }

  // Check if entitlements are stale and need a refresh
  const cachedAt = user.dupr_entitlements_cached_at
    ? new Date(user.dupr_entitlements_cached_at).getTime()
    : 0;
  const isStale = Date.now() - cachedAt > ENTITLEMENTS_MAX_AGE_MS;

  if (isStale) {
    await refreshEntitlements(userId);
  }
}

/**
 * Attempt to refresh a user's entitlements from DUPR.
 * If the user has lost BASIC_L1, revoke their verification.
 * Network/token errors are swallowed — the webhook will catch changes.
 */
async function refreshEntitlements(userId: string): Promise<void> {
  try {
    const admin = createAdminClient();

    // Read the user's stored DUPR tokens (service_role bypasses RLS)
    const { data: tokenRow, error: tokenError } = await admin
      .from("dupr_tokens")
      .select("access_token, refresh_token, token_expires_at")
      .eq("user_id", userId)
      .single();

    if (tokenError || !tokenRow) {
      console.warn("Entitlement refresh: no DUPR token for user", userId);
      return;
    }

    let accessToken = tokenRow.access_token;

    // If the token is expired, try to refresh it
    const tokenExpiry = new Date(tokenRow.token_expires_at).getTime();
    if (Date.now() >= tokenExpiry) {
      try {
        const refreshed = await refreshUserToken(tokenRow.refresh_token);
        accessToken = refreshed.accessToken;

        // Store the new tokens
        await admin
          .from("dupr_tokens")
          .update({
            access_token: refreshed.accessToken,
            refresh_token: refreshed.refreshToken,
            token_expires_at: new Date(
              Date.now() + refreshed.expiresIn * 1000,
            ).toISOString(),
          })
          .eq("user_id", userId);
      } catch (refreshErr) {
        // A 401 from DUPR means the refresh token itself has been revoked or
        // the account is gone. Silently returning here would leave a verified
        // flag on an account DUPR no longer recognises, so revoke it.
        const is401 =
          refreshErr instanceof Error &&
          refreshErr.message.includes("(401)");
        if (is401) {
          console.warn(
            "Entitlement refresh: DUPR rejected refresh token (401), revoking verification for user",
            userId,
          );
          await admin
            .from("users")
            .update({ dupr_verified: false })
            .eq("id", userId);
          throw new DuprGateError(
            "DUPR verification revoked — session expired",
          );
        }

        console.warn("Entitlement refresh: token refresh failed for user", userId, refreshErr);
        // Non-401 failure (network, 5xx) — don't block the user,
        // the webhook will eventually catch entitlement changes
        return;
      }
    }

    // Fetch current entitlements from DUPR
    const { entitlements } = await getUserEntitlements(accessToken);

    // Update cached entitlements
    await admin
      .from("users")
      .update({
        dupr_entitlements: entitlements,
        dupr_entitlements_cached_at: new Date().toISOString(),
      })
      .eq("id", userId);

    // If the user no longer has BASIC_L1, revoke verification
    if (!entitlements.includes("BASIC_L1")) {
      console.warn("Entitlement refresh: user lost BASIC_L1, revoking verification", userId);

      await admin
        .from("users")
        .update({ dupr_verified: false })
        .eq("id", userId);

      throw new DuprGateError("DUPR verification revoked — BASIC_L1 entitlement lost");
    }
  } catch (err) {
    // Re-throw DuprGateError (revocation) so it propagates to the caller
    if (err instanceof DuprGateError) {
      throw err;
    }
    // Swallow all other errors (network failures, DUPR API downtime, etc.)
    console.warn("Entitlement refresh failed (non-blocking):", err);
  }
}

/**
 * Custom error so callers can distinguish gate failures from other errors
 * and return 403 instead of 500.
 */
export class DuprGateError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DuprGateError";
  }
}
