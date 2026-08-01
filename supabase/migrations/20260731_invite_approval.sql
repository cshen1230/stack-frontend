-- Session invite policy, with an approval path that doesn't strand a session that needs a
-- player.
--
-- Plain owner-approval fails exactly when it matters: it's 5pm, the game is at 6, the session
-- is a player short, and the host is driving or already on court. Nobody gets added.
--
-- The rule here keeps what approval is actually for — two people agreeing — and widens only
-- the question of who the second person may be as the game approaches:
--
--   more than 3h before start   the host approves
--   within 3h of start          any confirmed participant approves
--   at any distance             the proposer never approves their own request
--
-- That last line is what stops this collapsing into no approval at all.
--
-- Everything here is additive. Existing rows keep today's behaviour: invite_policy defaults to
-- 'open', which is what invite-to-game already does (any confirmed participant or the creator
-- adds directly).

alter table public.games
    add column if not exists invite_policy text not null default 'open'
        check (invite_policy in ('open', 'approval', 'owner_only'));

-- Who proposed a participant, so an approver can be checked against them. Null for rows that
-- predate this and for people who joined under 'open'.
alter table public.game_participants
    add column if not exists invited_by uuid references public.users(id) on delete set null;

alter table public.game_participants
    add column if not exists approved_by uuid references public.users(id) on delete set null;

-- rsvp_status gains 'pending_approval'. A pending participant is NOT counted in
-- games.spots_filled — the seat is only taken once someone approves, so a stalled request
-- never silently holds a place.
do $$
begin
    if exists (
        select 1 from information_schema.check_constraints
        where constraint_name = 'game_participants_rsvp_status_check'
    ) then
        alter table public.game_participants
            drop constraint game_participants_rsvp_status_check;
    end if;
end $$;

alter table public.game_participants
    add constraint game_participants_rsvp_status_check
    check (rsvp_status in ('confirmed', 'waitlisted', 'cancelled', 'pending_approval'));

create index if not exists idx_game_participants_pending
    on public.game_participants(game_id)
    where rsvp_status = 'pending_approval';


-- Can p_approver approve p_participant's pending request?
--
-- Mirrors SessionApproval in the client so both halves answer the same question the same way.
--
-- SECURITY DEFINER because this has to see the whole roster to answer. Run as the caller, an
-- RLS policy hiding one game_participants row would come back as "you can't approve that" —
-- a permission bug that looks exactly like the rule working. It leaks nothing: both ids are
-- arguments and the answer is one boolean about them.
create or replace function can_approve_participant(
    p_approver UUID,
    p_participant_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_game          public.games%ROWTYPE;
    v_participant   public.game_participants%ROWTYPE;
    v_handed_over   BOOLEAN;
    v_is_member     BOOLEAN;
BEGIN
    SELECT * INTO v_participant
    FROM public.game_participants
    WHERE id = p_participant_id;

    IF NOT FOUND OR v_participant.rsvp_status <> 'pending_approval' THEN
        RETURN FALSE;
    END IF;

    -- Approving your own request is not two people agreeing.
    IF v_participant.invited_by = p_approver THEN
        RETURN FALSE;
    END IF;

    -- Nor is approving yourself into a session.
    IF v_participant.user_id = p_approver THEN
        RETURN FALSE;
    END IF;

    SELECT * INTO v_game FROM public.games WHERE id = v_participant.game_id;
    IF NOT FOUND OR v_game.is_cancelled THEN
        RETURN FALSE;
    END IF;

    IF v_game.creator_id = p_approver THEN
        RETURN TRUE;
    END IF;

    IF v_game.invite_policy = 'owner_only' THEN
        RETURN FALSE;
    END IF;

    -- Inside the handover window anyone already playing can approve; they are the ones at the
    -- court, and they know more about the situation than the host does.
    v_handed_over := v_game.game_datetime - now() <= interval '3 hours';

    SELECT EXISTS (
        SELECT 1 FROM public.game_participants
        WHERE game_id = v_game.id
          AND user_id = p_approver
          AND rsvp_status = 'confirmed'
    ) INTO v_is_member;

    RETURN v_handed_over AND v_is_member;
END;
$$;


-- Pending requests an approver can currently act on, for the session's approvals queue.
--
-- p_user_id is ignored for signed-in callers — it always answers for whoever is asking. The
-- argument survives only so the service role can ask on someone's behalf (notifications).
-- Without that, SECURITY DEFINER here would let any user read anyone else's queue.
create or replace function pending_approvals_for_user(p_user_id UUID DEFAULT NULL)
RETURNS TABLE (
    participant_id  UUID,
    game_id         UUID,
    user_id         UUID,
    first_name      TEXT,
    last_name       TEXT,
    avatar_url      TEXT,
    dupr_rating     DOUBLE PRECISION,
    invited_by      UUID,
    game_datetime   TIMESTAMPTZ
)
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT
        gp.id           AS participant_id,
        gp.game_id,
        gp.user_id,
        u.first_name,
        u.last_name,
        u.avatar_url,
        u.dupr_rating,
        gp.invited_by,
        g.game_datetime
    FROM public.game_participants gp
    JOIN public.users u ON u.id = gp.user_id
    JOIN public.games g ON g.id = gp.game_id
    WHERE gp.rsvp_status = 'pending_approval'
      AND NOT g.is_cancelled
      AND can_approve_participant(coalesce(auth.uid(), p_user_id), gp.id)
    ORDER BY g.game_datetime;
$$;

revoke execute on function pending_approvals_for_user(UUID) from public;
grant  execute on function pending_approvals_for_user(UUID) to authenticated, service_role;

revoke execute on function can_approve_participant(UUID, UUID) from public;
grant  execute on function can_approve_participant(UUID, UUID) to authenticated, service_role;


-- The edge functions for this are written and live in the repo:
--
--   invite-to-game       adds as 'pending_approval' with invited_by = caller, and skips the
--                        seat increment, when invite_policy <> 'open' and the caller isn't the
--                        creator.
--   approve-participant  new; guards on can_approve_participant(), claims the row with an
--                        `.eq('rsvp_status','pending_approval')` filter so two approvers racing
--                        can't both take the seat, then increments via increment_spots_filled
--                        and rolls the row back to pending if the game filled meanwhile.
--
-- Both are committed but NOT deployed by committing. Run:
--     ./supabase/functions/sync.sh deploy invite-to-game approve-participant
-- and apply THIS migration first — invite-to-game writes invited_by, and the column has to
-- exist before it does.
--
-- Note that increment_spots_filled() has no source in this repo either; it exists only on the
-- server. Same class of gap as the missing functions, on the database side.
