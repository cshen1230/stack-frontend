/**
 * SMS invitation channel — wraps Twilio so the rest of the codebase talks to
 * an `InvitationChannel` and the provider can be swapped later.
 */

// ── Types ───────────────────────────────────────────────────

export interface InvitationChannel {
  sendInvite(to: string, body: string): Promise<string | null>; // returns SID
  sendNotification(to: string, body: string): Promise<string | null>;
  validateInbound(req: Request, body: string): Promise<boolean>;
  parseInbound(params: URLSearchParams): InboundMessage;
}

export interface InboundMessage {
  from: string;
  body: string;
  messageSid: string;
}

export interface GameSummary {
  sessionName: string | null;
  creatorName: string;
  gameDatetime: string; // human-readable
  locationName: string | null;
  gameFormat: string;
  roster: string[]; // display names of confirmed players
}

/** What the brand is called in a message. Carriers require it in the first one. */
export const BRAND = "StackPickleball";

// ── Phone normalisation ─────────────────────────────────────

/**
 * Normalises common US phone formats into E.164, or returns null.
 *
 * Returning null matters more than the parsing does. The previous version ended in a
 * best-effort `+${digits}`, which meant a typo, an extension, or a pasted street number all
 * came back looking like a phone number and went out as a real billed send to whoever owns it.
 * A number we cannot confidently parse is a number we should refuse, not guess at.
 */
export function normalizePhoneNumber(raw: string): string | null {
  const trimmed = (raw ?? "").trim();
  const digits = trimmed.replace(/\D/g, "");

  // Written as international already: trust the country code, sanity-check the length.
  if (trimmed.startsWith("+")) {
    return digits.length >= 8 && digits.length <= 15 ? `+${digits}` : null;
  }

  // NANP, with or without the country code. The first digit of an area code and of an exchange
  // is 2-9, which is what separates a real number from ten digits of something else.
  if (digits.length === 11 && digits.startsWith("1")) {
    const nanp = digits.slice(1);
    return /^[2-9]\d{2}[2-9]\d{6}$/.test(nanp) ? `+${digits}` : null;
  }
  if (digits.length === 10) {
    return /^[2-9]\d{2}[2-9]\d{6}$/.test(digits) ? `+1${digits}` : null;
  }

  return null;
}

// ── Reserved number detection ────────────────────────────────

/**
 * Returns `true` for numbers that should never receive an invitation SMS:
 *
 * - **555 area codes** — reserved for fictional use (e.g. 555-0100..0199 are
 *   explicitly set aside; the whole exchange is treated as suspect).
 * - **N11 service codes** (211, 311, 411, 511, 611, 711, 811, 911) — these are
 *   three-digit service numbers, not subscriber lines.
 *
 * Call this after `normalizePhoneNumber` with the E.164 result.
 */
export function isReservedNumber(e164: string): boolean {
  // Strip the country code to get the 10-digit national number.
  const national = e164.startsWith("+1") ? e164.slice(2) : null;
  if (!national || national.length !== 10) return false;

  // 555 area code
  if (national.startsWith("555")) return true;

  // 555 exchange within any area code (NPA-555-xxxx)
  if (national.slice(3, 6) === "555") return true;

  // N11 codes — these are three-digit service numbers, but if someone enters
  // them as 10-digit (e.g. 911-xxx-xxxx) they should still be blocked.
  const areaCode = national.slice(0, 3);
  if (/^[2-9]11$/.test(areaCode)) return true;

  return false;
}

// ── Time ────────────────────────────────────────────────────

/** Used when a game predates games.timezone and so has no zone of its own. */
export const DEFAULT_TIMEZONE =
  Deno.env.get("DEFAULT_TIMEZONE") ?? "America/Los_Angeles";

/**
 * Renders an instant in the zone the session belongs to.
 *
 * Without an explicit zone this falls to the runtime's, and the edge runtime is UTC — which is
 * how a 6pm Pacific game came out of the formatter as "01:00 AM" the next day. The zone is a
 * property of the session, not of whoever happens to be rendering it.
 */
export function formatGameTime(
  isoDatetime: string,
  timezone: string | null | undefined,
): string {
  const zone = timezone || DEFAULT_TIMEZONE;
  const date = new Date(isoDatetime);
  try {
    return new Intl.DateTimeFormat("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      timeZoneName: "short",
      timeZone: zone,
    }).format(date);
  } catch {
    // A bad zone string must not cost someone their invitation.
    return new Intl.DateTimeFormat("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      timeZoneName: "short",
      timeZone: DEFAULT_TIMEZONE,
    }).format(date);
  }
}

// ── SMS templates ───────────────────────────────────────────

/**
 * The first message a number ever receives from us, and the only one carriers actually inspect.
 *
 * A US A2P 10DLC campaign is approved against sample copy that names the sender and tells the
 * recipient how to stop. Copy without those gets the campaign rejected, and unregistered
 * traffic on a 10DLC number gets filtered as error 30034 — the messages simply never arrive,
 * with nothing in our logs saying they didn't. So the brand and the opt-out line are not
 * politeness, they are the difference between the feature working and silently not.
 */
export function formatInviteSMS(inviterName: string, game: GameSummary): string {
  const title = game.sessionName ?? `${game.creatorName}'s Session`;
  const lines = [
    `${BRAND}: ${inviterName} invited you to play pickleball!`,
    "",
    title,
    `${game.gameFormat} · ${game.gameDatetime}`,
  ];
  if (game.locationName) lines.push(game.locationName);
  if (game.roster.length > 0) {
    lines.push("", `Playing: ${game.roster.join(", ")}`);
  }
  lines.push("", "Reply Y to join or N to pass. STOP to opt out, HELP for help.");
  return lines.join("\n");
}

export function formatHelpSMS(): string {
  return `${BRAND}: we text you when a friend invites you to a pickleball session. Reply Y to join, N to pass, CANCEL to drop out, STOP to opt out. Msg&data rates may apply.`;
}

/**
 * The confirmation for STOP.
 *
 * Twilio's default opt-out handling normally answers STOP itself and blocks the number before
 * anything reaches us. This exists for the case where that handling is turned off, and it is
 * deliberately the last message we ever send to that number.
 */
export function formatOptOutSMS(): string {
  return `${BRAND}: you're unsubscribed and won't get any more messages from us.`;
}

export function formatAcceptedSMS(game: GameSummary): string {
  const title = game.sessionName ?? `${game.creatorName}'s Session`;
  return `You're in! See you at ${title} — ${game.gameDatetime}.${game.locationName ? "\n" + game.locationName : ""}\n\nReply CANCEL to drop out.`;
}

export function formatDeclinedSMS(): string {
  return "Got it — maybe next time! You can always reply Y if you change your mind (as long as spots remain).";
}

export function formatCancelledSMS(): string {
  return "Done — you've been removed from the session. Reply Y to rejoin if spots are open.";
}

export function formatGameCancelledSMS(game: GameSummary): string {
  const title = game.sessionName ?? `${game.creatorName}'s Session`;
  return `Heads up: ${title} on ${game.gameDatetime} has been cancelled by the organizer.`;
}

export function formatGameFullSMS(): string {
  return "Sorry, that session is full. We'll let you know if a spot opens up.";
}

export function formatExpiredSMS(): string {
  return "That session has already started — too late to change your RSVP.";
}

export function formatAlreadyRepliedSMS(current: string): string {
  if (current === "accepted") {
    return "You've already joined this session. Reply CANCEL to drop out.";
  }
  if (current === "declined") {
    return "You already passed on this one. Reply Y to join if you changed your mind.";
  }
  return "You've already responded to this invitation.";
}

export function formatUnrecognizedSMS(): string {
  return "Reply Y to join, N to pass, or CANCEL to drop out.";
}

export function formatNoInvitationFoundSMS(): string {
  return "No pending invitation found for this number. If you were invited, the session may have filled up or been cancelled.";
}

// ── Twilio implementation ───────────────────────────────────

/**
 * Compares two signatures without letting the comparison time say how much of the guess was
 * right. `===` bails at the first differing byte, which over enough attempts hands an attacker
 * the signature one character at a time.
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export class TwilioSMSChannel implements InvitationChannel {
  private accountSid: string;
  private authToken: string;
  private fromNumber: string;

  constructor() {
    // Checked rather than asserted: with `!` a missing variable becomes the string "undefined",
    // which produces a well-formed `Authorization: Basic …` header and a 401 from Twilio that
    // reads like a credentials problem instead of a configuration one.
    const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
    const authToken = Deno.env.get("TWILIO_AUTH_TOKEN");
    const fromNumber = Deno.env.get("TWILIO_PHONE_NUMBER");

    const missing = [
      ["TWILIO_ACCOUNT_SID", accountSid],
      ["TWILIO_AUTH_TOKEN", authToken],
      ["TWILIO_PHONE_NUMBER", fromNumber],
    ].filter(([, v]) => !v).map(([k]) => k);

    if (missing.length > 0) {
      throw new Error(`SMS is not configured: missing ${missing.join(", ")}`);
    }

    this.accountSid = accountSid!;
    this.authToken = authToken!;
    this.fromNumber = fromNumber!;
  }

  async sendInvite(to: string, body: string): Promise<string | null> {
    return this.send(to, body);
  }

  async sendNotification(to: string, body: string): Promise<string | null> {
    return this.send(to, body);
  }

  /** Validate Twilio's X-Twilio-Signature header (HMAC-SHA1). */
  async validateInbound(req: Request, rawBody: string): Promise<boolean> {
    const signature = req.headers.get("X-Twilio-Signature");
    if (!signature) return false;

    const webhookUrl = Deno.env.get("TWILIO_WEBHOOK_URL");
    if (!webhookUrl) return false;

    const params = new URLSearchParams(rawBody);
    // Twilio signs the URL followed by every parameter, sorted by name, as name then value.
    // getAll rather than get: a repeated parameter contributes each of its values in order,
    // and taking only the first silently produces a different digest and a 403 nobody can
    // explain.
    const sortedKeys = [...new Set(params.keys())].sort();
    let data = webhookUrl;
    for (const key of sortedKeys) {
      for (const value of params.getAll(key)) data += key + value;
    }

    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(this.authToken),
      { name: "HMAC", hash: "SHA-1" },
      false,
      ["sign"],
    );
    const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(data));
    const expected = btoa(String.fromCharCode(...new Uint8Array(sig)));
    return timingSafeEqual(expected, signature);
  }

  parseInbound(params: URLSearchParams): InboundMessage {
    return {
      from: params.get("From") ?? "",
      body: (params.get("Body") ?? "").trim(),
      messageSid: params.get("MessageSid") ?? "",
    };
  }

  // ── private ─────────────────────────────────────────────

  private async send(to: string, body: string): Promise<string | null> {
    const url = `https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`;
    const form = new URLSearchParams({
      To: to,
      From: this.fromNumber,
      Body: body,
    });
    const resp = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization:
          "Basic " + btoa(`${this.accountSid}:${this.authToken}`),
      },
      body: form.toString(),
    });
    if (!resp.ok) {
      const err = await resp.text();
      console.error("Twilio send error:", err);
      return null;
    }
    const json = await resp.json();
    return json.sid ?? null;
  }
}
