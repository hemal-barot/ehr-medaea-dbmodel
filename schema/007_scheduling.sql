-- ============================================================
-- Medaea EHR — Schema Migration 007: Scheduling Domain
-- Version: 1.0.0 | Date: 2026-04-03 | Phase: 1
-- Tables: pto_requests, availability_rules, schedule_templates,
--         rooms, room_bookings, staff_schedules, on_call_assignments
-- ============================================================


-- ─── PTO Requests ─────────────────────────────────────────────────────────────
-- Provider time-off requests: PTO, sick leave, conference days, blocked time.

CREATE TABLE IF NOT EXISTS pto_requests (
    id                  VARCHAR     PRIMARY KEY,
    user_id             VARCHAR     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id     VARCHAR     REFERENCES organizations(id) ON DELETE SET NULL,
    type                VARCHAR(20) NOT NULL,
                        -- PTO | Sick | Conference | Blocked
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',
                        -- pending | approved | denied
    date_from           VARCHAR(10) NOT NULL,                -- ISO date YYYY-MM-DD
    date_to             VARCHAR(10) NOT NULL,                -- ISO date YYYY-MM-DD
    duration            VARCHAR(50),                         -- Human label e.g., "5 days"
    coverage_provider   VARCHAR(200),                        -- Free-text name of covering provider
    reason              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pto_user_id ON pto_requests (user_id);
CREATE INDEX IF NOT EXISTS idx_pto_org_id ON pto_requests (organization_id);

COMMENT ON TABLE pto_requests IS 'Provider time-off and leave requests. Status transitions: pending → approved | denied.';


-- ─── Availability Rules ───────────────────────────────────────────────────────
-- Automated scheduling constraints: buffer time, double-booking prevention, etc.

CREATE TABLE IF NOT EXISTS availability_rules (
    id              VARCHAR     PRIMARY KEY,
    organization_id VARCHAR     REFERENCES organizations(id) ON DELETE SET NULL,
    name            VARCHAR(200) NOT NULL,                   -- Rule display name
    type            VARCHAR(50) NOT NULL,
                    -- Buffer | Break | Conflict | Double Booking | Advance Booking | Block
    priority        INTEGER     NOT NULL DEFAULT 1,          -- Lower = higher priority
    description     TEXT,
    applies_to      VARCHAR(100) NOT NULL DEFAULT 'All Providers',
    conditions      TEXT,                                    -- Rule condition logic (free-text/JSON future)
    enabled         BOOLEAN     NOT NULL DEFAULT TRUE,
    created_by      VARCHAR     REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rules_org_id ON availability_rules (organization_id);

COMMENT ON TABLE availability_rules IS 'Scheduling rules: buffer time, conflict prevention, advance booking limits, etc.';


-- ─── Schedule Templates ───────────────────────────────────────────────────────
-- Reusable weekly schedule templates for providers, departments, or the whole clinic.

CREATE TABLE IF NOT EXISTS schedule_templates (
    id              VARCHAR     PRIMARY KEY,
    organization_id VARCHAR     REFERENCES organizations(id) ON DELETE SET NULL,
    name            VARCHAR(200) NOT NULL,
    badge           VARCHAR(30) NOT NULL DEFAULT 'Provider',
                    -- Provider | Department | Clinic
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
                    -- active | inactive
    description     TEXT,
    days            VARCHAR(100),                            -- Human label e.g., "Monday – Friday"
    hours           VARCHAR(100),                            -- Human label e.g., "8:00 AM – 5:00 PM"
    types           VARCHAR(500),                            -- Comma-separated visit types
    applied_to      VARCHAR(200),                            -- Free-text scope (e.g., "All Providers")
    usage_count     INTEGER     NOT NULL DEFAULT 0,
    created_by      VARCHAR     REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_templates_org_id ON schedule_templates (organization_id);

COMMENT ON TABLE schedule_templates IS 'Reusable schedule templates. Applied to providers, departments, or entire clinic.';


-- ─── Rooms ────────────────────────────────────────────────────────────────────
-- Physical exam rooms and clinic resources.

CREATE TABLE IF NOT EXISTS rooms (
    id              VARCHAR     PRIMARY KEY,
    organization_id VARCHAR     REFERENCES organizations(id) ON DELETE SET NULL,
    name            VARCHAR(100) NOT NULL,                   -- e.g., "Exam Room 1", "Procedure Suite A"
    type            VARCHAR(50),
                    -- General | Procedure | Specialty | Consult | Diagnostic | Telehealth
    icon            VARCHAR(50) NOT NULL DEFAULT 'fa-door-open',
                    -- Font Awesome icon class
    status          VARCHAR(20) NOT NULL DEFAULT 'available',
                    -- available | occupied | reserved | maintenance
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rooms_org_id ON rooms (organization_id);

COMMENT ON TABLE rooms IS 'Physical exam rooms and clinic resources with real-time status tracking.';


-- ─── Room Bookings ────────────────────────────────────────────────────────────
-- Time-slot bookings for a room, optionally tied to an appointment.

CREATE TABLE IF NOT EXISTS room_bookings (
    id              VARCHAR     PRIMARY KEY,
    room_id         VARCHAR     NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    appointment_id  VARCHAR     REFERENCES appointments(id) ON DELETE SET NULL,
    patient_name    VARCHAR(200),                            -- Denormalized for display
    doctor_name     VARCHAR(200),                            -- Denormalized for display
    booking_date    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    start_hour      INTEGER     NOT NULL,                    -- 0-23 (24h format)
    start_min       INTEGER     NOT NULL DEFAULT 0,          -- 0 or 30 (half-hour slots)
    duration_min    INTEGER     NOT NULL DEFAULT 30,         -- Duration in minutes
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_room_bookings_room_id ON room_bookings (room_id);
CREATE INDEX IF NOT EXISTS idx_room_bookings_date ON room_bookings (booking_date);

COMMENT ON TABLE room_bookings IS 'Room time-slot reservations. Linked to rooms and optionally to appointments.';


-- ─── Staff Schedules ──────────────────────────────────────────────────────────
-- Weekly shift schedule per provider.

CREATE TABLE IF NOT EXISTS staff_schedules (
    id              VARCHAR     PRIMARY KEY,
    user_id         VARCHAR     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id VARCHAR     REFERENCES organizations(id) ON DELETE SET NULL,
    mon             VARCHAR(50),                             -- "8:00 AM – 5:00 PM" or "Off"
    tue             VARCHAR(50),
    wed             VARCHAR(50),
    thu             VARCHAR(50),
    fri             VARCHAR(50),
    sat             VARCHAR(50) NOT NULL DEFAULT 'Off',
    sun             VARCHAR(50) NOT NULL DEFAULT 'Off',
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
                    -- active | pto
    effective_from  VARCHAR(10),                             -- ISO date when schedule takes effect
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_staff_schedules_user_id ON staff_schedules (user_id);

COMMENT ON TABLE staff_schedules IS 'Weekly provider shift schedules. Mon-Sun shift labels or "Off".';


-- ─── On-Call Assignments ─────────────────────────────────────────────────────
-- On-call period assignments for after-hours coverage.

CREATE TABLE IF NOT EXISTS on_call_assignments (
    id              VARCHAR     PRIMARY KEY,
    user_id         VARCHAR     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id VARCHAR     REFERENCES organizations(id) ON DELETE SET NULL,
    backup_user_id  VARCHAR     REFERENCES users(id) ON DELETE SET NULL,
    period_label    VARCHAR(200),                            -- e.g., "Tonight 6 PM – 6 AM"
    start_at        TIMESTAMPTZ,
    end_at          TIMESTAMPTZ,
    status          VARCHAR(20) NOT NULL DEFAULT 'upcoming',
                    -- active | upcoming | completed
    total_calls     INTEGER     NOT NULL DEFAULT 0,
    emergencies     INTEGER     NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_on_call_user_id ON on_call_assignments (user_id);

COMMENT ON TABLE on_call_assignments IS 'After-hours on-call assignments. Tracks primary provider and backup with call metrics.';
