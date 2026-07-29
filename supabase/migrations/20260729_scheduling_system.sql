-- ============================================================
-- Scheduling System Migration
-- Adds recurring schedule, device tokens, and friend-aware RPCs
-- ============================================================

-- 1. user_schedules: recurring weekly availability windows
CREATE TABLE IF NOT EXISTS user_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),  -- 0=Sunday, 6=Saturday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    preferred_format TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, day_of_week, start_time)
);

ALTER TABLE user_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own schedules"
    ON user_schedules FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own schedules"
    ON user_schedules FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own schedules"
    ON user_schedules FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own schedules"
    ON user_schedules FOR DELETE
    USING (auth.uid() = user_id);


-- 2. user_devices: push token storage for future APNs
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, device_token)
);

ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own devices"
    ON user_devices FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own devices"
    ON user_devices FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices"
    ON user_devices FOR DELETE
    USING (auth.uid() = user_id);


-- 3. Add available_from to available_players
ALTER TABLE available_players
    ADD COLUMN IF NOT EXISTS available_from TIMESTAMPTZ DEFAULT now();


-- 4. RPC: friends_ready_to_play
--    Returns friends who have active availability right now.
CREATE OR REPLACE FUNCTION friends_ready_to_play(p_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    first_name TEXT,
    last_name TEXT,
    dupr_rating DOUBLE PRECISION,
    dupr_verified BOOLEAN,
    avatar_url TEXT,
    available_from TIMESTAMPTZ,
    available_until TIMESTAMPTZ,
    preferred_format TEXT,
    note TEXT
)
LANGUAGE sql STABLE
AS $$
    SELECT
        u.id            AS user_id,
        u.username,
        u.first_name,
        u.last_name,
        u.dupr_rating,
        u.dupr_verified,
        u.avatar_url,
        ap.available_from,
        ap.available_until,
        ap.preferred_format,
        ap.note
    FROM available_players ap
    JOIN users u ON u.id = ap.user_id
    JOIN friendships f
        ON f.status = 'accepted'
        AND (
            (f.user_id = p_user_id AND f.friend_id = ap.user_id)
            OR
            (f.friend_id = p_user_id AND f.user_id = ap.user_id)
        )
    WHERE ap.status = 'available'
      AND ap.available_until > now()
    ORDER BY ap.available_from DESC;
$$;


-- 5. RPC: friends_schedules
--    Returns recurring schedule windows for friends on a given day of week.
CREATE OR REPLACE FUNCTION friends_schedules(p_user_id UUID, p_day_of_week INT)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    first_name TEXT,
    last_name TEXT,
    dupr_rating DOUBLE PRECISION,
    dupr_verified BOOLEAN,
    avatar_url TEXT,
    start_time TIME,
    end_time TIME,
    preferred_format TEXT
)
LANGUAGE sql STABLE
AS $$
    SELECT
        u.id            AS user_id,
        u.username,
        u.first_name,
        u.last_name,
        u.dupr_rating,
        u.dupr_verified,
        u.avatar_url,
        us.start_time,
        us.end_time,
        us.preferred_format
    FROM user_schedules us
    JOIN users u ON u.id = us.user_id
    JOIN friendships f
        ON f.status = 'accepted'
        AND (
            (f.user_id = p_user_id AND f.friend_id = us.user_id)
            OR
            (f.friend_id = p_user_id AND f.user_id = us.user_id)
        )
    WHERE us.day_of_week = p_day_of_week
    ORDER BY us.start_time ASC;
$$;
