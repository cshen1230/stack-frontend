-- Detects whether a user already has a confirmed session whose 90-minute window
-- overlaps with a proposed game time. Called from every join path (create, RSVP,
-- invite, approve) so two sessions can't silently double-book the same person.
--
-- Returns one row per conflict (LIMIT 1) so the caller can build a human-readable
-- error. Returns nothing when the slot is clear.

CREATE OR REPLACE FUNCTION check_schedule_conflict(
    p_user_id       UUID,
    p_game_datetime TIMESTAMPTZ,
    p_exclude_game_id UUID DEFAULT NULL
)
RETURNS TABLE(
    conflicting_game_id     UUID,
    conflicting_datetime    TIMESTAMPTZ,
    conflicting_session_name TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT g.id, g.game_datetime, g.session_name
    FROM game_participants gp
    JOIN games g ON g.id = gp.game_id
    WHERE gp.user_id   = p_user_id
      AND gp.rsvp_status = 'confirmed'
      AND g.is_cancelled = FALSE
      AND g.game_datetime > now() - INTERVAL '90 minutes'   -- skip past sessions
      AND (p_exclude_game_id IS NULL OR g.id != p_exclude_game_id)
      -- Two 90-minute windows overlap when each starts before the other ends.
      AND p_game_datetime < g.game_datetime + INTERVAL '90 minutes'
      AND p_game_datetime + INTERVAL '90 minutes' > g.game_datetime
    LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION check_schedule_conflict(UUID, TIMESTAMPTZ, UUID)
    TO authenticated, service_role;
