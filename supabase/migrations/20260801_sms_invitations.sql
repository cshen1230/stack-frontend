-- SMS Invitations: let organizers invite non-app-users by phone number.
-- Invitees reply Y/N/CANCEL via SMS; their RSVP is tracked here instead of
-- game_participants (no auth.users row → no FK target).

-- ============================================================
-- sms_invitations
-- ============================================================
CREATE TABLE IF NOT EXISTS sms_invitations (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id       UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    invited_by    UUID NOT NULL REFERENCES auth.users(id),
    invitee_name  TEXT NOT NULL,
    phone_number  TEXT NOT NULL,                 -- E.164 format
    rsvp_status   TEXT NOT NULL DEFAULT 'pending'
                  CHECK (rsvp_status IN ('pending', 'accepted', 'declined', 'cancelled')),
    sms_sid       TEXT,                          -- Twilio outbound message SID
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (game_id, phone_number)
);

CREATE INDEX IF NOT EXISTS idx_sms_invitations_phone   ON sms_invitations (phone_number);
CREATE INDEX IF NOT EXISTS idx_sms_invitations_game    ON sms_invitations (game_id);

-- Partial index for the webhook: find the most recent actionable invitation fast.
CREATE INDEX IF NOT EXISTS idx_sms_invitations_actionable
    ON sms_invitations (phone_number, created_at DESC)
    WHERE rsvp_status IN ('pending', 'accepted');

-- Auto-touch updated_at
CREATE OR REPLACE FUNCTION touch_sms_invitation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sms_invitations_updated_at ON sms_invitations;
CREATE TRIGGER trg_sms_invitations_updated_at
    BEFORE UPDATE ON sms_invitations
    FOR EACH ROW EXECUTE FUNCTION touch_sms_invitation_updated_at();

-- RLS: block all client writes; SELECT only for inviter or game creator.
ALTER TABLE sms_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sms_invitations_select ON sms_invitations;
CREATE POLICY sms_invitations_select ON sms_invitations
    FOR SELECT
    USING (
        auth.uid() = invited_by
        OR auth.uid() = (SELECT creator_id FROM games WHERE id = game_id)
    );

-- No INSERT / UPDATE / DELETE policies → clients can only read.
-- Edge functions use the admin (service-role) client for writes.

-- ============================================================
-- sms_log  (admin-only audit trail)
-- ============================================================
CREATE TABLE IF NOT EXISTS sms_log (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invitation_id UUID REFERENCES sms_invitations(id) ON DELETE SET NULL,
    direction     TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    phone_number  TEXT NOT NULL,
    message_body  TEXT NOT NULL,
    twilio_sid    TEXT,
    status        TEXT,                          -- Twilio delivery status
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE sms_log ENABLE ROW LEVEL SECURITY;
-- No policies → invisible to all clients.  Admin client bypasses RLS.
