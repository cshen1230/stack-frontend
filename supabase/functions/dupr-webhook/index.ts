import { createAdminClient } from "../_shared/supabase-client.ts";

/**
 * Receives DUPR rating update webhooks.
 * No Supabase auth required — this is called by DUPR servers via our proxy.
 * Must respond quickly (200 OK) to satisfy DUPR webhook requirements.
 */
Deno.serve(async (req) => {
  // DUPR sends a GET/HEAD handshake during webhook registration — respond 200
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Validate shared secret from proxy — fail closed if the env var is unset.
  const webhookSecret = Deno.env.get("WEBHOOK_SECRET");
  if (!webhookSecret) {
    console.error("WEBHOOK_SECRET is not configured — rejecting all webhook calls");
    return new Response("Forbidden", { status: 403 });
  }

  const incomingSecret = req.headers.get("x-webhook-secret");
  if (incomingSecret !== webhookSecret) {
    console.error("Webhook secret mismatch");
    return new Response("Forbidden", { status: 403 });
  }

  try {
    const body = await req.json();

    // Secondary validation: clientId matches our DUPR_CLIENT_ID
    const expectedClientId = Deno.env.get("DUPR_CLIENT_ID");
    if (body.clientId !== expectedClientId) {
      // Truncate the incoming clientId in logs to avoid leaking a full key
      // from a misconfigured caller.
      const truncated = typeof body.clientId === "string"
        ? body.clientId.slice(0, 8) + "…"
        : "(non-string)";
      console.error("Webhook clientId mismatch:", truncated);
      return new Response("Forbidden", { status: 403 });
    }

    // Only handle RATING events
    if (body.event !== "RATING") {
      // Acknowledge but ignore non-rating events
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const message = body.message;
    if (!message?.duprId || !message?.rating) {
      console.error("Webhook missing duprId or rating:", body);
      return new Response("Bad request", { status: 400 });
    }

    const { duprId, rating } = message;
    const singlesRating = rating.singles != null ? Number(rating.singles) : null;
    const doublesRating = rating.doubles != null ? Number(rating.doubles) : null;

    // Use doubles as primary rating; fall back to singles
    const primaryRating = doublesRating ?? singlesRating;

    // Update user ratings
    const admin = createAdminClient();

    const { error: updateError } = await admin
      .from("users")
      .update({
        dupr_singles_rating: singlesRating,
        dupr_doubles_rating: doublesRating,
        dupr_rating: primaryRating,
      })
      .eq("dupr_id", duprId);

    if (updateError) {
      console.error("Webhook user update failed:", updateError);
      // Still return 200 so DUPR doesn't retry endlessly
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Webhook error:", err);
    // Return 200 to prevent DUPR from retrying on parse errors
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
});
