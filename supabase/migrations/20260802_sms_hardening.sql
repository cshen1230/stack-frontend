-- Follow-up to 20260801_sms_invitations.sql. Three things the first pass left open, all
-- additive and all safe to re-run.
--
--   1. games.timezone     — every SMS was quoting times in UTC
--   2. roster visibility  — accepted SMS invitees counted toward spots_filled but were
--                           invisible to everyone except the inviter and the host
--   3. sms_opt_outs       — STOP had nowhere to be recorded


-- ============================================================
-- 1. Games carry the zone they were created in
-- ============================================================
--
-- game_datetime is a timestamptz, so the instant was never wrong — but an instant alone can't
-- be written into a text message. Rendering it needed a zone, nothing supplied one, and the
-- edge runtime is UTC, so a 6pm Pacific game went out as "01:00 AM" the following day.
--
-- The zone belongs on the game rather than on the reader: a pickleball session happens at a
-- court, in that court's local time, and it reads the same to a player who is out of town.
-- Null means "written before this column existed" — callers fall back to a default.

alter table public.games
    add column if not exists timezone text;

comment on column public.games.timezone is
    'IANA zone the session is scheduled in (e.g. America/Los_Angeles). Set from the creator''s '
    'device. Used to render times for anyone reading them outside the app, notably SMS.';


-- ============================================================
-- 2. SMS invitees are part of the roster, so the roster can see them
-- ============================================================
--
-- 20260801 let only the inviter and the game creator read sms_invitations. But an accepted SMS
-- invitee takes a real seat — spots_filled counts them — so everyone else saw "6 of 8 in" over
-- five names and no way to find the sixth. A player the count knows about and the roster does
-- not is worse than either showing them or not counting them.

create or replace function public.can_view_game_roster(p_game_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    -- SECURITY DEFINER so this answers the same way for everyone. Asked as the caller, an RLS
    -- policy on games or game_participants would fold into "no", and a permission bug would be
    -- indistinguishable from not being on the roster.
    SELECT EXISTS (
        SELECT 1 FROM public.games g
        WHERE g.id = p_game_id AND g.creator_id = p_user_id
    ) OR EXISTS (
        SELECT 1 FROM public.game_participants gp
        WHERE gp.game_id = p_game_id
          AND gp.user_id = p_user_id
          AND gp.rsvp_status = 'confirmed'
    );
$$;

revoke execute on function public.can_view_game_roster(UUID, UUID) from public;
grant  execute on function public.can_view_game_roster(UUID, UUID) to authenticated, service_role;

drop policy if exists sms_invitations_select on public.sms_invitations;

create policy sms_invitations_select on public.sms_invitations
    FOR SELECT
    USING (
        auth.uid() = invited_by
        OR public.can_view_game_roster(game_id, auth.uid())
    );

-- Still no INSERT / UPDATE / DELETE policies — writes go through the edge functions on the
-- service-role client.
--
-- Note what stays hidden: phone_number is in this table, and any confirmed player can now read
-- the row. That is deliberate and it is the point of a roster, but it means the client must not
-- put a phone number on screen for anyone but the person who typed it in.


-- ============================================================
-- 3. Opt-outs are permanent and checked before every send
-- ============================================================
--
-- Twilio blocks delivery to a number that has replied STOP, but it blocks it at send time, as a
-- 21610 on a message we have already decided to bill ourselves for and already recorded as an
-- invitation. Keeping our own list means an opted-out number stops being invited at all, and
-- the person who tried gets told why rather than watching an invite sit at "pending" forever.

create table if not exists public.sms_opt_outs (
    phone_number  TEXT PRIMARY KEY,          -- E.164
    opted_out_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    source        TEXT NOT NULL DEFAULT 'sms_reply'
                  CHECK (source IN ('sms_reply', 'manual', 'carrier'))
);

alter table public.sms_opt_outs enable row level security;
-- No policies: this is nobody's business but the edge functions', which use the service role.


-- ============================================================
-- Backfill guards for 20260801, in case it was applied before this file existed
-- ============================================================

create index if not exists idx_sms_invitations_phone
    on public.sms_invitations (phone_number);
create index if not exists idx_sms_invitations_game
    on public.sms_invitations (game_id);
create index if not exists idx_sms_invitations_actionable
    on public.sms_invitations (phone_number, created_at DESC)
    where rsvp_status in ('pending', 'accepted');

-- Rate limiting reads "how many invites has this account sent lately", which is a scan over
-- invited_by ordered by time.
create index if not exists idx_sms_invitations_inviter_recent
    on public.sms_invitations (invited_by, created_at DESC);


-- ============================================================
-- 4. Tell an invitation apart from a reply in the log
-- ============================================================
--
-- The per-recipient cap counts how many times we have cold-texted a number today. Counting
-- outbound rows flat would fold in the confirmations someone gets *because* they replied —
-- so accepting an invitation would push you toward your own limit, and two sessions in a day
-- would lock you out. Only unsolicited messages should count against it.

alter table public.sms_log
    add column if not exists kind text not null default 'notification'
        check (kind in ('invite', 'notification', 'reply'));

create index if not exists idx_sms_log_recipient_invites
    on public.sms_log (phone_number, created_at DESC)
    where direction = 'outbound' and kind = 'invite';
