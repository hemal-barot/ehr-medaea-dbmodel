-- ============================================================
-- Medaea EHR — Schema Migration 003: Appointments
-- Version: 1.0.0 | Date: 2026-04-03 | Phase: 1
-- Tables: appointments
-- ============================================================

CREATE TABLE IF NOT EXISTS appointments (
    id                  VARCHAR     PRIMARY KEY,
    patient_id          VARCHAR     REFERENCES patients(id) ON DELETE SET NULL,
    provider_id         VARCHAR     REFERENCES users(id) ON DELETE SET NULL,

    -- Denormalized patient name (for display without JOIN when patient deleted)
    patient_first_name  VARCHAR     NOT NULL,
    patient_last_name   VARCHAR     NOT NULL,

    -- Scheduling
    start_time          TIMESTAMPTZ NOT NULL,
    end_time            TIMESTAMPTZ,
    duration_minutes    INTEGER     NOT NULL DEFAULT 30,

    -- Visit details
    visit_type          VARCHAR(50),
                        -- New Patient | Follow-up | Annual Exam | Sick Visit
                        -- Procedure | Telehealth | Consult | Wellness
    room                VARCHAR(100),
    condition_type      VARCHAR(50),                          -- Acute | Chronic | Preventive
    reason              TEXT,
    status              VARCHAR(30) NOT NULL DEFAULT 'scheduled',
                        -- scheduled | confirmed | in_progress | completed | cancelled | no_show
    location            VARCHAR(255),
    location_type       VARCHAR(20),                          -- in-person | telehealth
    notes               TEXT,

    -- Foreign keys
    organization_id     VARCHAR     REFERENCES organizations(id),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_appointments_provider_id ON appointments (provider_id);
CREATE INDEX IF NOT EXISTS idx_appointments_patient_id ON appointments (patient_id);
CREATE INDEX IF NOT EXISTS idx_appointments_start_time ON appointments (start_time);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments (status);
CREATE INDEX IF NOT EXISTS idx_appointments_org_id ON appointments (organization_id);

COMMENT ON TABLE appointments IS 'Appointment scheduling. Linked to patient, provider, and organization.';
COMMENT ON COLUMN appointments.duration_minutes IS 'Default 30 minutes. Used by calendar for time-slot rendering.';
COMMENT ON COLUMN appointments.status IS 'State machine: scheduled → confirmed → in_progress → completed. Also: cancelled, no_show.';
COMMENT ON COLUMN appointments.patient_first_name IS 'Denormalized — preserved even if patient record is deleted. Required for billing audit trail.';
