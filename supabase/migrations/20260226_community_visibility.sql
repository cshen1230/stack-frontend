-- ============================================================
-- Community Visibility: column, updated RPC, search RPC
-- ============================================================

-- 1. Add visibility column to group_chats
ALTER TABLE public.group_chats
    ADD COLUMN visibility text NOT NULL DEFAULT 'private'
    CHECK (visibility IN ('public', 'invite_only', 'private'));

-- 2. Update my_group_chats RPC to include visibility
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

-- 3. New RPC: search_discoverable_communities
-- Returns public + invite_only communities where the user is NOT a member
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
      AND gc.name ILIKE '%' || p_query || '%'
      AND NOT EXISTS (
          SELECT 1 FROM public.group_chat_members gcm
          WHERE gcm.group_chat_id = gc.id AND gcm.user_id = p_user_id
      )
    ORDER BY (SELECT count(*) FROM public.group_chat_members m WHERE m.group_chat_id = gc.id) DESC
    LIMIT 20;
$$;
