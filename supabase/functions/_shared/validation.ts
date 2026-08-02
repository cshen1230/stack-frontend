/**
 * Shared input validation and error sanitisation for edge functions.
 */

// ── Coordinate validation ────────────────────────────────────

/**
 * Validates latitude/longitude before they are interpolated into a PostGIS
 * `POINT(lng lat)` string. Without this an attacker can inject arbitrary SQL
 * fragments through a number field.
 */
export function validateCoordinates(
  lat: unknown,
  lng: unknown,
): { latitude: number; longitude: number } | null {
  if (lat == null || lng == null) return null;

  const latitude = Number(lat);
  const longitude = Number(lng);

  if (Number.isNaN(latitude) || Number.isNaN(longitude)) return null;
  if (latitude < -90 || latitude > 90) return null;
  if (longitude < -180 || longitude > 180) return null;

  return { latitude, longitude };
}

// ── Content-Type guard ───────────────────────────────────────

/**
 * Returns a 415 Response if the request is not JSON.
 * Call after the OPTIONS check, before `req.json()`.
 *
 * Skips GET/HEAD/OPTIONS since those never carry a body.
 */
export function requireJsonContentType(req: Request): Response | null {
  const method = req.method.toUpperCase();
  if (method === "GET" || method === "HEAD" || method === "OPTIONS") {
    return null;
  }

  const ct = req.headers.get("content-type") ?? "";
  if (ct.includes("application/json")) return null;

  return new Response(
    JSON.stringify({ error: "Content-Type must be application/json" }),
    {
      status: 415,
      headers: { "Content-Type": "application/json" },
    },
  );
}

// ── Error sanitisation ───────────────────────────────────────

/**
 * Known-safe validation error whose message can be shown to the client.
 * Throw one of these from validation code; the catch block will recognise it
 * and use the message directly rather than replacing it with a generic string.
 */
export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

/**
 * Logs the real error server-side and returns a generic message for the client.
 *
 * If the error is a `ValidationError`, the message is considered safe and is
 * returned as-is (these are messages we wrote, not database or runtime errors).
 */
export function sanitizeErrorForClient(
  err: unknown,
  context?: string,
): string {
  if (err instanceof ValidationError) return err.message;

  // Log the full error so it's available in the function logs.
  if (context) {
    console.error(`[${context}]`, err);
  } else {
    console.error(err);
  }

  return "An internal error occurred. Please try again.";
}
