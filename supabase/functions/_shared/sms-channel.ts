/**
 * SMS invitation channel — wraps Twilio so the rest of the codebase talks to
 * an `InvitationChannel` and the provider can be swapped later.
 */

// ── Types ───────────────────────────────────────────────────

export interface InvitationChannel {
  sendInvite(to: string, body: string): Promise<string | null>; // returns SID
  sendNotification(to: string, body: string): Promise<void>;
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

// ── Phone normalisation ─────────────────────────────────────

/** Normalises common US phone formats into E.164 (+1XXXXXXXXXX). */
export function normalizePhoneNumber(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith("1")) return `+${digits}`;
  if (raw.startsWith("+") && digits.length >= 10) return `+${digits}`;
  return `+${digits}`; // best-effort
}

// ── SMS templates ───────────────────────────────────────────

export function formatInviteSMS(inviterName: string, game: GameSummary): string {
  const title = game.sessionName ?? `${game.creatorName}'s Session`;
  const lines = [
    `${inviterName} invited you to play pickleball!`,
    "",
    title,
    `${game.gameFormat} · ${game.gameDatetime}`,
  ];
  if (game.locationName) lines.push(game.locationName);
  if (game.roster.length > 0) {
    lines.push("", `Playing: ${game.roster.join(", ")}`);
  }
  lines.push("", "Reply Y to join or N to pass.");
  return lines.join("\n");
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

export class TwilioSMSChannel implements InvitationChannel {
  private accountSid: string;
  private authToken: string;
  private fromNumber: string;

  constructor() {
    this.accountSid = Deno.env.get("TWILIO_ACCOUNT_SID")!;
    this.authToken = Deno.env.get("TWILIO_AUTH_TOKEN")!;
    this.fromNumber = Deno.env.get("TWILIO_PHONE_NUMBER")!;
  }

  async sendInvite(to: string, body: string): Promise<string | null> {
    return this.send(to, body);
  }

  async sendNotification(to: string, body: string): Promise<void> {
    await this.send(to, body);
  }

  /** Validate Twilio's X-Twilio-Signature header (HMAC-SHA1). */
  async validateInbound(req: Request, rawBody: string): Promise<boolean> {
    const signature = req.headers.get("X-Twilio-Signature");
    if (!signature) return false;

    const webhookUrl = Deno.env.get("TWILIO_WEBHOOK_URL");
    if (!webhookUrl) return false;

    const params = new URLSearchParams(rawBody);
    // Twilio signs url + sorted params concatenated as key=value
    const sortedKeys = [...params.keys()].sort();
    let data = webhookUrl;
    for (const key of sortedKeys) {
      data += key + params.get(key);
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
    return expected === signature;
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
