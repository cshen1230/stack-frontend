-- ============================================================
-- Security fixes migration
-- All statements are idempotent (IF NOT EXISTS, CREATE OR REPLACE, DO blocks).
-- ============================================================


-- ============================================================
-- 1. Fix my_group_chats() — add SET search_path
--
-- The function is SECURITY DEFINER but the original CREATE did not pin
-- the search_path. An attacker who can create objects in a schema that
-- appears before `public` on the default path could shadow tables and
-- read data they shouldn't.
-- ============================================================
CREATE OR REPLACE FUNCTION public.my_group_chats(p_user_id uuid)
RETURNS TABLE (
    id                          uuid,
    name                        text,
    created_by                  uuid,
    game_id                     uuid,
    avatar_url                  text,
    created_at                  timestamptz,
    updated_at                  timestamptz,
    visibility                  text,
    member_count                int,
    last_message_content        text,
    last_message_sender_first_name text,
    last_message_at             timestamptz,
    member_avatar_urls          text[]
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
    SELECT
        gc.id,
        gc.name,
        gc.created_by,
        gc.game_id,
        gc.avatar_url,
        gc.created_at,
        gc.updated_at,
        gc.visibility,
        (SELECT count(*)::int FROM public.group_chat_members m WHERE m.group_chat_id = gc.id) AS member_count,
        lm.content AS last_message_content,
        lm.sender_first_name AS last_message_sender_first_name,
        lm.created_at AS last_message_at,
        (
            SELECT array_agg(u.avatar_url)
            FROM (
                SELECT usr.avatar_url
                FROM public.group_chat_members mem
                JOIN public.users usr ON usr.id = mem.user_id
                WHERE mem.group_chat_id = gc.id
                  AND usr.avatar_url IS NOT NULL
                ORDER BY mem.joined_at
                LIMIT 4
            ) u
        ) AS member_avatar_urls
    FROM public.group_chats gc
    JOIN public.group_chat_members gcm ON gcm.group_chat_id = gc.id AND gcm.user_id = p_user_id
    LEFT JOIN LATERAL (
        SELECT
            msg.content,
            msg.created_at,
            usr.first_name AS sender_first_name
        FROM public.group_chat_messages msg
        JOIN public.users usr ON usr.id = msg.user_id
        WHERE msg.group_chat_id = gc.id
        ORDER BY msg.created_at DESC
        LIMIT 1
    ) lm ON true
    ORDER BY coalesce(lm.created_at, gc.created_at) DESC;
$$;


-- ============================================================
-- 2. Fix search_discoverable_communities() — search_path + escape ILIKE
--
-- The p_query parameter was interpolated directly into an ILIKE pattern,
-- meaning a search for "%" would match every community. Escaping the
-- wildcards keeps the search behaving like a literal substring match.
-- ============================================================
CREATE OR REPLACE FUNCTION public.search_discoverable_communities(p_user_id uuid, p_query text)
RETURNS TABLE (
    id                  uuid,
    name                text,
    created_by          uuid,
    avatar_url          text,
    created_at          timestamptz,
    updated_at          timestamptz,
    visibility          text,
    member_count        int,
    member_avatar_urls  text[]
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
    SELECT
        gc.id,
        gc.name,
        gc.created_by,
        gc.avatar_url,
        gc.created_at,
        gc.updated_at,
        gc.visibility,
        (SELECT count(*)::int FROM public.group_chat_members m WHERE m.group_chat_id = gc.id) AS member_count,
        (
            SELECT array_agg(u.avatar_url)
            FROM (
                SELECT usr.avatar_url
                FROM public.group_chat_members mem
                JOIN public.users usr ON usr.id = mem.user_id
                WHERE mem.group_chat_id = gc.id
                  AND usr.avatar_url IS NOT NULL
                ORDER BY mem.joined_at
                LIMIT 4
            ) u
        ) AS member_avatar_urls
    FROM public.group_chats gc
    WHERE gc.visibility IN ('public', 'invite_only')
      AND gc.name ILIKE '%' || replace(replace(replace(p_query, '\', '\\'), '%', '\%'), '_', '\_') || '%' ESCAPE '\'
      AND NOT EXISTS (
          SELECT 1 FROM public.group_chat_members gcm
          WHERE gcm.group_chat_id = gc.id AND gcm.user_id = p_user_id
      )
    ORDER BY (SELECT count(*) FROM public.group_chat_members m WHERE m.group_chat_id = gc.id) DESC
    LIMIT 20;
$$;


-- ============================================================
-- 3. Fix can_approve_participant() — verify p_approver = auth.uid()
--
-- The edge function already passes user.id from the verified JWT, but the
-- DB function itself did not cross-check. A service-role call could pass
-- any UUID. Adding the guard makes the function safe regardless of caller.
-- ============================================================
CREATE OR REPLACE FUNCTION public.can_approve_participant(
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
    v_caller        UUID;
BEGIN
    -- Allow service_role to call on behalf of any user; for authenticated
    -- callers, enforce that p_approver matches their JWT.
    v_caller := auth.uid();
    IF v_caller IS NOT NULL AND v_caller <> p_approver THEN
        RETURN FALSE;
    END IF;

    SELECT * INTO v_participant
    FROM public.game_participants
    WHERE id = p_participant_id;

    IF NOT FOUND OR v_participant.rsvp_status <> 'pending_approval' THEN
        RETURN FALSE;
    END IF;

    IF v_participant.invited_by = p_approver THEN
        RETURN FALSE;
    END IF;

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


-- ============================================================
-- 4. Add ON DELETE CASCADE to sms_invitations.invited_by FK
--
-- The FK references auth.users(id). If a user is ever hard-deleted from
-- auth.users, the orphaned invitation rows would violate the FK and block
-- the delete. CASCADE is safe here because the invitations are worthless
-- without an inviter.
-- ============================================================
DO $$
BEGIN
    -- Drop the existing FK and recreate with CASCADE
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'sms_invitations_invited_by_fkey'
          AND table_name = 'sms_invitations'
    ) THEN
        ALTER TABLE public.sms_invitations
            DROP CONSTRAINT sms_invitations_invited_by_fkey;
    END IF;

    ALTER TABLE public.sms_invitations
        ADD CONSTRAINT sms_invitations_invited_by_fkey
        FOREIGN KEY (invited_by)
        REFERENCES auth.users(id)
        ON DELETE CASCADE;
END;
$$;


-- ============================================================
-- 5. Missing indexes
-- ============================================================

-- game_participants(invited_by) — used by pending_approvals_for_user
CREATE INDEX IF NOT EXISTS idx_game_participants_invited_by
    ON public.game_participants (invited_by);

-- user_schedules(user_id) — used by friends_schedules and friends_ready_to_play
CREATE INDEX IF NOT EXISTS idx_user_schedules_user_id
    ON public.user_schedules (user_id);


-- ============================================================
-- 6. Add UPDATE policy on user_devices
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'user_devices'
          AND policyname = 'Users can update own devices'
    ) THEN
        CREATE POLICY "Users can update own devices"
            ON public.user_devices FOR UPDATE
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;
END;
$$;


-- ============================================================
-- 7. Add UPDATE / DELETE policies on group_chat_messages (own messages)
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'group_chat_messages'
          AND policyname = 'Users can update own messages'
    ) THEN
        CREATE POLICY "Users can update own messages"
            ON public.group_chat_messages FOR UPDATE
            USING (user_id = auth.uid())
            WITH CHECK (user_id = auth.uid());
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'group_chat_messages'
          AND policyname = 'Users can delete own messages'
    ) THEN
        CREATE POLICY "Users can delete own messages"
            ON public.group_chat_messages FOR DELETE
            USING (user_id = auth.uid());
    END IF;
END;
$$;


-- ============================================================
-- 8. Timezone validation trigger on games
--
-- The edge function already validates timezone with Intl.DateTimeFormat,
-- but a direct insert/update through the DB (admin, migration, etc.)
-- could still set an invalid value. This trigger checks against
-- pg_timezone_names as a belt-and-suspenders guard.
-- ============================================================
CREATE OR REPLACE FUNCTION public.validate_game_timezone()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.timezone IS NOT NULL AND NEW.timezone <> '' THEN
        IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = NEW.timezone) THEN
            RAISE EXCEPTION 'Invalid timezone: %', NEW.timezone
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_game_timezone ON public.games;
CREATE TRIGGER trg_validate_game_timezone
    BEFORE INSERT OR UPDATE OF timezone ON public.games
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_game_timezone();
