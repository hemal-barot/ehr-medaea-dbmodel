-- ============================================================
-- Medaea EHR — Schema Migration 006: Audit Logs
-- Version: 1.0.0 | Date: 2026-04-03 | Phase: 1
-- Tables: audit_logs
-- ============================================================
-- HIPAA §164.312(b) — Audit Controls
-- All access to PHI must be logged and retained for 6 years.
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id              VARCHAR     PRIMARY KEY,
    user_id         VARCHAR     REFERENCES users(id) ON DELETE SET NULL,
                    -- NULL for unauthenticated actions (failed logins, etc.)
    action          VARCHAR(100) NOT NULL,
                    -- login | logout | view_patient | create_patient | update_patient
                    -- create_encounter | view_encounter | export_record | failed_login
                    -- mfa_verify | password_reset | account_created
    resource_type   VARCHAR(50),
                    -- patient | encounter | appointment | user | document | allergy | medication
    resource_id     VARCHAR,                                 -- UUID of the accessed resource
    details         TEXT,                                    -- Human-readable action description
    ip_address      VARCHAR(45),                             -- IPv4 or IPv6
    user_agent      VARCHAR(500),                            -- Browser/client user agent
    phi_accessed    BOOLEAN     NOT NULL DEFAULT FALSE,      -- TRUE if PHI was accessed (HIPAA critical)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user_id ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_phi ON audit_logs (phi_accessed) WHERE phi_accessed = TRUE;
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs (action);

COMMENT ON TABLE audit_logs IS 'HIPAA §164.312(b) audit control log. All PHI access events must be recorded and retained for 6 years minimum.';
COMMENT ON COLUMN audit_logs.phi_accessed IS 'TRUE when Protected Health Information was accessed. Critical for HIPAA compliance reporting.';
COMMENT ON COLUMN audit_logs.user_id IS 'NULL allowed for unauthenticated events (failed login attempts, rate limit triggers).';
