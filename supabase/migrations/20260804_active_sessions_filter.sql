-- Redefine my_active_sessions to exclude past sessions.
--
-- The previous definition (not captured in migrations) did not filter on
-- game_datetime, so sessions from days or weeks ago stayed in the "active"
-- list indefinitely. The cutoff mirrors the assumed 90-minute duration the
-- rest of the app uses: a session is still "active" until its window ends.

DROP FUNCTION IF EXISTS my_active_sessions(UUID);

CREATE FUNCTION my_active_sessions(p_user_id UUID)
RETURNS TABLE(
    id                  UUID,
    creator_id          UUID,
    game_datetime       TIMESTAMPTZ,
    location_name       TEXT,
    skill_level_min     DOUBLE PRECISION,
    skill_level_max     DOUBLE PRECISION,
    spots_available     INT,
    spots_filled        INT,
    game_format         TEXT,
    session_name        TEXT,
    session_type        TEXT,
    num_rounds          INT,
    round_robin_status  TEXT,
    description         TEXT,
    is_cancelled        BOOLEAN,
    friends_only        BOOLEAN,
    created_at          TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ,
    latitude            DOUBLE PRECISION,
    longitude           DOUBLE PRECISION,
    creator_username    TEXT,
    creator_first_name  TEXT,
    creator_last_name   TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        g.id,
        g.creator_id,
        g.game_datetime,
        g.location_name,
        g.skill_level_min,
        g.skill_level_max,
        g.spots_available,
        g.spots_filled,
        g.game_format,
        g.session_name,
        g.session_type,
        g.num_rounds,
        g.round_robin_status,
        g.description,
        g.is_cancelled,
        g.friends_only,
        g.created_at,
        g.updated_at,
        ST_Y(g.location::geometry) AS latitude,
        ST_X(g.location::geometry) AS longitude,
        u.username        AS creator_username,
        u.first_name      AS creator_first_name,
        u.last_name       AS creator_last_name
    FROM game_participants gp
    JOIN games g ON g.id = gp.game_id
    JOIN users u ON u.id = g.creator_id
    WHERE gp.user_id     = p_user_id
      AND gp.rsvp_status = 'confirmed'
      AND g.is_cancelled = FALSE
      AND g.game_datetime > now() - INTERVAL '90 minutes'
    ORDER BY g.game_datetime ASC;
$$;

GRANT EXECUTE ON FUNCTION my_active_sessions(UUID) TO authenticated, service_role;
