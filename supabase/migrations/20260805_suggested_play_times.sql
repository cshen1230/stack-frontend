-- Suggest play times from past game history.
--
-- Aggregates confirmed past games (created or joined) by day-of-week and hour
-- in the caller's timezone, returning the top 3 slots played at least twice.
-- The client shows the top result as a planning shortcut on the home screen.

CREATE OR REPLACE FUNCTION suggested_play_times(p_user_id UUID, p_timezone TEXT)
RETURNS TABLE(
    day_of_week INT,
    hour_of_day INT,
    play_count  BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT
        EXTRACT(DOW FROM g.game_datetime AT TIME ZONE p_timezone)::INT  AS day_of_week,
        EXTRACT(HOUR FROM g.game_datetime AT TIME ZONE p_timezone)::INT AS hour_of_day,
        COUNT(*)                                                        AS play_count
    FROM game_participants gp
    JOIN games g ON g.id = gp.game_id
    WHERE gp.user_id     = p_user_id
      AND gp.rsvp_status = 'confirmed'
      AND g.is_cancelled = FALSE
      AND g.game_datetime < now()
    GROUP BY 1, 2
    HAVING COUNT(*) >= 2
    ORDER BY play_count DESC
    LIMIT 3;
$$;

GRANT EXECUTE ON FUNCTION suggested_play_times(UUID, TEXT) TO authenticated, service_role;
