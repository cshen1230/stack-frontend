/**
 * In-memory token-bucket rate limiter for auth endpoints.
 *
 * Edge functions run as short-lived isolates, so this only limits bursts
 * within a single isolate lifetime — it won't survive a cold start. That is
 * acceptable: the goal is to stop automated credential-stuffing loops that hit
 * the same warm instance hundreds of times per minute, not to replace a WAF.
 */

interface Bucket {
  tokens: number;
  lastRefill: number;
}

const buckets = new Map<string, Bucket>();

// Prevent the map from growing without bound if an attacker rotates IPs.
const MAX_BUCKETS = 10_000;

/**
 * Returns `true` if the request is allowed, `false` if rate-limited.
 *
 * @param key      Typically the client IP or a composite key.
 * @param capacity Maximum burst size (tokens in a full bucket).
 * @param refillMs How often one token is added back (milliseconds).
 */
export function rateLimit(
  key: string,
  capacity: number = 5,
  refillMs: number = 12_000, // 1 token every 12s ≈ 5/min
): boolean {
  const now = Date.now();
  let bucket = buckets.get(key);

  if (!bucket) {
    if (buckets.size >= MAX_BUCKETS) {
      // Evict the oldest bucket to cap memory.
      const oldest = buckets.keys().next().value;
      if (oldest !== undefined) buckets.delete(oldest);
    }
    bucket = { tokens: capacity, lastRefill: now };
    buckets.set(key, bucket);
  }

  // Refill tokens based on elapsed time.
  const elapsed = now - bucket.lastRefill;
  const refill = Math.floor(elapsed / refillMs);
  if (refill > 0) {
    bucket.tokens = Math.min(capacity, bucket.tokens + refill);
    bucket.lastRefill += refill * refillMs;
  }

  if (bucket.tokens <= 0) return false;

  bucket.tokens -= 1;
  return true;
}

/**
 * Extract the client IP from a Supabase edge function request.
 * Falls back to a fixed string so the limiter still works (just globally).
 */
export function clientIp(req: Request): string {
  return (
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    req.headers.get("cf-connecting-ip") ??
    "unknown"
  );
}
