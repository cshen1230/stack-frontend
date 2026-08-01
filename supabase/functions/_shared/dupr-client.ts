/**
 * DUPR API client helpers.
 *
 * API base URLs:
 *   UAT partner:    https://uat.mydupr.com/api
 *   UAT public:     https://api.uat.dupr.gg
 *   Prod partner:   https://prod.mydupr.com/api
 *   Prod public:    https://api.dupr.gg
 */

// ---------------------------------------------------------------------------
// Base URLs
// ---------------------------------------------------------------------------

function isProduction(): boolean {
  return Deno.env.get("DUPR_ENV") === "production";
}

export function getPartnerApiBase(): string {
  return isProduction()
    ? "https://prod.mydupr.com/api"
    : "https://uat.mydupr.com/api";
}

export function getPublicApiBase(): string {
  return isProduction()
    ? "https://api.dupr.gg"
    : "https://api.uat.dupr.gg";
}

// ---------------------------------------------------------------------------
// Partner token (server-to-server auth)
// ---------------------------------------------------------------------------

interface PartnerTokenResponse {
  accessToken: string;
  expiresIn: number;
}

/**
 * Obtain a 1-hour partner access token using ClientKey:ClientSecret.
 * POST /auth/v1.0/token
 */
export async function getPartnerToken(): Promise<PartnerTokenResponse> {
  const clientKey = Deno.env.get("DUPR_CLIENT_KEY")!;
  const clientSecret = Deno.env.get("DUPR_CLIENT_SECRET")!;

  // Base64-encode "ClientKey:ClientSecret"
  const credentials = btoa(`${clientKey}:${clientSecret}`);

  const res = await fetch(`${getPartnerApiBase()}/auth/v1.0/token`, {
    method: "POST",
    headers: {
      "x-authorization": credentials,
      "Content-Type": "application/json",
    },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`DUPR partner token failed (${res.status}): ${text}`);
  }

  const data = await res.json();
  const result = data.result ?? data;

  return {
    accessToken: result.token ?? result.accessToken,
    expiresIn: result.expiry
      ? Math.floor((new Date(result.expiry).getTime() - Date.now()) / 1000)
      : 3600,
  };
}

// ---------------------------------------------------------------------------
// User-scoped API calls (using the user's own access token from SSO)
// ---------------------------------------------------------------------------

interface DuprUserInfo {
  duprId: string;
  fullName: string;
  firstName: string;
  lastName: string;
  singlesRating: number | null;
  doublesRating: number | null;
  singlesReliability: number | null;
  doublesReliability: number | null;
}

/**
 * GET /public/user/info — returns the authenticated user's basic profile.
 */
export async function getUserBasicInfo(
  userAccessToken: string,
): Promise<DuprUserInfo> {
  const res = await fetch(`${getPublicApiBase()}/public/user/info`, {
    headers: { Authorization: `Bearer ${userAccessToken}` },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`DUPR getUserBasicInfo failed (${res.status}): ${text}`);
  }

  const data = await res.json();

  // The DUPR API nests the result in a `result` key
  const user = data.result ?? data;

  const fullName: string = user.fullName ?? user.name ?? "";

  // Extract first/last name from dedicated fields or fall back to splitting fullName
  let firstName: string = user.firstName ?? user.first_name ?? "";
  let lastName: string = user.lastName ?? user.last_name ?? "";
  if (!firstName && !lastName && fullName) {
    const parts = fullName.trim().split(/\s+/);
    firstName = parts[0] ?? "";
    lastName = parts.slice(1).join(" ");
  }

  return {
    duprId: String(user.duprId ?? user.id),
    fullName,
    firstName,
    lastName,
    singlesRating: user.singlesRating != null ? Number(user.singlesRating) : null,
    doublesRating: user.doublesRating != null ? Number(user.doublesRating) : null,
    singlesReliability: user.singlesReliability != null ? Number(user.singlesReliability) : null,
    doublesReliability: user.doublesReliability != null ? Number(user.doublesReliability) : null,
  };
}

// ---------------------------------------------------------------------------
// Entitlements / subscriptions
// ---------------------------------------------------------------------------

interface EntitlementResponse {
  entitlements: string[]; // e.g. ["BASIC_L1", "PREMIUM_L1", "VERIFIED_L1"]
}

/**
 * POST /subscription/active — returns the user's active entitlements.
 */
export async function getUserEntitlements(
  userAccessToken: string,
): Promise<EntitlementResponse> {
  const res = await fetch(`${getPublicApiBase()}/subscription/active`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${userAccessToken}`,
      "Content-Type": "application/json",
    },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`DUPR getUserEntitlements failed (${res.status}): ${text}`);
  }

  const data = await res.json();
  const result = data.result ?? data;

  // Normalize: the API may return an array of objects or strings
  const entitlements: string[] = Array.isArray(result)
    ? result.map((e: { name?: string } | string) =>
        typeof e === "string" ? e : e.name ?? ""
      ).filter(Boolean)
    : [];

  return { entitlements };
}

// ---------------------------------------------------------------------------
// Webhook subscription (partner-scoped)
// ---------------------------------------------------------------------------

/**
 * Subscribe one or more DUPR users to RATING webhook events.
 * POST /user/v1.0/subscribe/webhook-event
 */
export async function subscribeUserToWebhook(
  partnerAccessToken: string,
  duprIds: string[],
): Promise<void> {
  const res = await fetch(
    `${getPartnerApiBase()}/user/v1.0/subscribe/webhook-event`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${partnerAccessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ duprIds, topics: ["RATING"] }),
    },
  );

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`DUPR subscribeUserToWebhook failed (${res.status}): ${text}`);
  }
}

// ---------------------------------------------------------------------------
// Token refresh
// ---------------------------------------------------------------------------

interface RefreshTokenResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

/**
 * Refresh a user's DUPR access token.
 * GET /auth/v2.0/refresh with x-refresh-token header.
 */
export async function refreshUserToken(
  currentRefreshToken: string,
): Promise<RefreshTokenResponse> {
  const res = await fetch(`${getPartnerApiBase()}/auth/v2.0/refresh`, {
    headers: { "x-refresh-token": currentRefreshToken },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`DUPR refreshUserToken failed (${res.status}): ${text}`);
  }

  return res.json();
}

// ---------------------------------------------------------------------------
// Webhook registration (one-time setup)
// ---------------------------------------------------------------------------

/**
 * Register our webhook URL with DUPR.
 * POST /v1.0/webhook
 */
export async function registerWebhook(
  partnerAccessToken: string,
  webhookUrl: string,
): Promise<unknown> {
  const clientId = Deno.env.get("DUPR_CLIENT_ID")!;

  const res = await fetch(`${getPartnerApiBase()}/v1.0/webhook`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${partnerAccessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      clientId,
      webhookUrl,
      topics: ["RATING"],
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`DUPR registerWebhook failed (${res.status}): ${text}`);
  }

  return res.json();
}
