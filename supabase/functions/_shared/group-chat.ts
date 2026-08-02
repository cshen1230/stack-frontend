export function pickChatCreatorId(chat: Record<string, unknown> | null | undefined): string | null {
  if (!chat) return null;
  const candidates = ["created_by", "creator_id", "owner_id", "user_id"];
  for (const key of candidates) {
    const v = (chat as Record<string, unknown>)[key];
    if (typeof v === "string" && v.length > 0) return v;
  }
  return null;
}

/** Escape characters that would be interpreted as HTML/XML markup. */
function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function serializeError(err: unknown) {
  const e = err as Record<string, unknown> | null;
  if (!e) return { message: escapeHtml(String(err)) };
  return {
    message: typeof e.message === "string" ? escapeHtml(e.message) : escapeHtml(String(err)),
    code: typeof e.code === "string" ? escapeHtml(e.code) : undefined,
    details: typeof e.details === "string" ? escapeHtml(e.details) : undefined,
    hint: typeof e.hint === "string" ? escapeHtml(e.hint) : undefined,
    status: typeof e.status === "number" ? e.status : undefined,
  };
}

export function isMissingColumnErrorMessage(msg: string, column: string) {
  const m = msg.toLowerCase();
  const c = column.toLowerCase();
  return m.includes("does not exist") && m.includes(c);
}

