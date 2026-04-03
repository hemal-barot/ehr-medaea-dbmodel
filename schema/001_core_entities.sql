-- ============================================================
-- Medaea EHR — Schema Migration 001: Core Entities
-- Version: 1.0.0 | Date: 2026-04-03 | Phase: 1
-- Tables: organizations, users, user_organizations
-- ============================================================

-- ─── Organizations ────────────────────────────────────────────────────────────
-- Root entity. All clinical data is scoped to an organization.
-- Represents a clinic, hospital, practice group, or health system.

CREATE TABLE IF NOT EXISTS organizations (
    id          VARCHAR     PRIMARY KEY,                        -- UUID v4
    name        VARCHAR     NOT NULL,                           -- Organization display name
    org_type    VARCHAR,                                        -- clinic | hospital | practice | urgent_care | telehealth
    address     TEXT,                                           -- Street address
    city        VARCHAR,
    state       VARCHAR(2),                                     -- 2-letter state abbreviation
    zip         VARCHAR(10),
    npi         VARCHAR(10),                                    -- National Provider Identifier (10-digit)
    tax_id      VARCHAR(20),                                    -- Federal Tax ID / EIN
    phone       VARCHAR(20),
    website     VARCHAR(255),
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE organizations IS 'Root entity — all clinical data scoped here. Represents clinics, hospitals, or practice groups.';
COMMENT ON COLUMN organizations.npi IS 'CMS National Provider Identifier — required for billing and ONC compliance';
COMMENT ON COLUMN organizations.tax_id IS 'Federal Tax ID / EIN — required for CMS claims and 1099 reporting';


-- ─── Users ────────────────────────────────────────────────────────────────────
-- All system users (providers, nurses, admins, staff).
-- Auth tokens, MFA, HIPAA consent, and credentials stored here.

CREATE TABLE IF NOT EXISTS users (
    id                          VARCHAR     PRIMARY KEY,
    email                       VARCHAR     NOT NULL UNIQUE,
    hashed_password             VARCHAR     NOT NULL,           -- bcrypt hash (cost=12)
    first_name                  VARCHAR     NOT NULL,
    last_name                   VARCHAR,
    phone                       VARCHAR(20),
    role                        VARCHAR     NOT NULL DEFAULT 'doctor',
                                                                -- doctor | nurse | admin | staff | billing | receptionist
    specialty                   VARCHAR,                        -- Internal Medicine | Cardiology | etc.
    npi                         VARCHAR(10),                    -- Individual NPI (Type 1)
    dea                         VARCHAR(20),                    -- DEA registration number
    license_number              VARCHAR(50),
    license_state               VARCHAR(2),
    license_expiry              VARCHAR(10),                    -- ISO date YYYY-MM-DD
    provider_type               VARCHAR(20),                    -- MD | DO | NP | PA | RN | MA
    avatar_url                  VARCHAR(500),
    is_active                   BOOLEAN     NOT NULL DEFAULT TRUE,
    is_verified                 BOOLEAN     NOT NULL DEFAULT FALSE,

    -- Email verification (expires in 24h)
    email_verification_token    VARCHAR,
    email_verification_expires  TIMESTAMPTZ,

    -- Password reset (expires in 1h)
    password_reset_token        VARCHAR,
    password_reset_expires      TIMESTAMPTZ,

    -- Multi-Factor Authentication
    mfa_enabled                 BOOLEAN     NOT NULL DEFAULT FALSE,
    mfa_method                  VARCHAR(20),                    -- authenticator | sms | email
    mfa_secret_encrypted        VARCHAR(500),                   -- AES-encrypted TOTP secret
    mfa_phone                   VARCHAR(20),                    -- E.164 phone for SMS MFA
    mfa_backup_codes            JSONB,                          -- Array of hashed backup codes

    -- HIPAA Consent
    hipaa_consent               BOOLEAN     NOT NULL DEFAULT FALSE,
    hipaa_consent_at            TIMESTAMPTZ,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at               TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_email_verification_token ON users (email_verification_token) WHERE email_verification_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_password_reset_token ON users (password_reset_token) WHERE password_reset_token IS NOT NULL;

COMMENT ON TABLE users IS 'All system users — providers, nurses, admins, staff. Authentication, MFA, HIPAA consent stored here.';
COMMENT ON COLUMN users.npi IS 'Type 1 NPI — individual provider identifier. Required for prescribing and billing.';
COMMENT ON COLUMN users.mfa_secret_encrypted IS 'AES-encrypted TOTP secret. Never stored in plaintext.';
COMMENT ON COLUMN users.hipaa_consent IS 'HIPAA §164.508 — authorization consent timestamp required for PHI access.';


-- ─── User Organizations ───────────────────────────────────────────────────────
-- Many-to-many join table. A user can belong to multiple organizations.
-- Stores per-organization role and department.

CREATE TABLE IF NOT EXISTS user_organizations (
    id              VARCHAR     PRIMARY KEY,
    user_id         VARCHAR     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id VARCHAR     NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role            VARCHAR     NOT NULL DEFAULT 'doctor',
    department      VARCHAR,                                    -- e.g. "Cardiology", "Emergency"
    permissions     JSONB                                       -- Future: granular feature permissions
);

CREATE INDEX IF NOT EXISTS idx_user_org_user_id ON user_organizations (user_id);
CREATE INDEX IF NOT EXISTS idx_user_org_org_id ON user_organizations (organization_id);

COMMENT ON TABLE user_organizations IS 'M:M join between users and organizations. A provider can belong to multiple clinics with different roles.';
