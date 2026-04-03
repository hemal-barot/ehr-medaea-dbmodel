-- ============================================================
-- Medaea EHR — Schema Migration 004: Clinical Records
-- Version: 1.0.0 | Date: 2026-04-03 | Phase: 1
-- Tables: encounters, allergies, medications, problems, immunizations
-- ============================================================
-- ONC/USCDI compliance:
--   • Encounters — SOAP notes (Subjective/Objective/Assessment/Plan)
--   • Allergies — SNOMED coding support
--   • Medications — NDC + RxNorm coding
--   • Problems — ICD-10 + SNOMED coding
--   • Immunizations — CVX codes (CDC vaccine codes)
-- ============================================================


-- ─── Encounters ───────────────────────────────────────────────────────────────
-- Core clinical documentation — SOAP notes.
-- Each encounter represents one patient visit with a provider.

CREATE TABLE IF NOT EXISTS encounters (
    id              VARCHAR     PRIMARY KEY,
    patient_id      VARCHAR     NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
    provider_id     VARCHAR     REFERENCES users(id) ON DELETE SET NULL,
    appointment_id  VARCHAR     REFERENCES appointments(id) ON DELETE SET NULL,
    encounter_type  VARCHAR(50),
                    -- Office Visit | Telehealth | Urgent Care | Annual Wellness
                    -- Procedure | Consult | Emergency
    chief_complaint TEXT,                                     -- Patient's presenting complaint (verbatim)
    subjective      TEXT,                                     -- S: History of present illness, ROS, history
    objective       TEXT,                                     -- O: Vitals, physical exam, labs, imaging
    assessment      TEXT,                                     -- A: Clinical impression, diagnoses
    plan            TEXT,                                     -- P: Treatment, orders, referrals, follow-up
    status          VARCHAR(20) NOT NULL DEFAULT 'open',
                    -- open | signed | amended
    encounter_date  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_encounters_patient_id ON encounters (patient_id);
CREATE INDEX IF NOT EXISTS idx_encounters_provider_id ON encounters (provider_id);
CREATE INDEX IF NOT EXISTS idx_encounters_date ON encounters (encounter_date DESC);

COMMENT ON TABLE encounters IS 'SOAP note encounters. Core clinical documentation. Each row = one patient visit.';
COMMENT ON COLUMN encounters.subjective IS 'SOAP S — HPI, review of systems, past medical/surgical/family/social history.';
COMMENT ON COLUMN encounters.objective IS 'SOAP O — Vitals, physical exam findings, lab results, imaging results.';
COMMENT ON COLUMN encounters.assessment IS 'SOAP A — Clinical assessment, differential diagnosis, working diagnoses.';
COMMENT ON COLUMN encounters.plan IS 'SOAP P — Orders, medications prescribed, referrals, follow-up instructions, patient education.';


-- ─── Allergies ────────────────────────────────────────────────────────────────
-- Patient allergy and adverse reaction list.
-- ONC USCDI v3: Allergy and Intolerance required.

CREATE TABLE IF NOT EXISTS allergies (
    id              VARCHAR     PRIMARY KEY,
    patient_id      VARCHAR     NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    allergen        VARCHAR(255) NOT NULL,                    -- Allergen name (e.g., "Penicillin")
    allergen_type   VARCHAR(30),                              -- drug | food | environmental | latex | contrast | other
    reaction        VARCHAR(255),                             -- Reaction description (e.g., "Anaphylaxis", "Rash")
    severity        VARCHAR(30),                              -- mild | moderate | severe | life-threatening
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
                    -- active | inactive | entered-in-error
    onset_date      VARCHAR(10),                             -- ISO date YYYY-MM-DD (approximate)
    snomed_code     VARCHAR(20),                             -- SNOMED CT concept ID
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE allergies IS 'Patient allergy and intolerance list. ONC USCDI v3 required data element.';
COMMENT ON COLUMN allergies.snomed_code IS 'SNOMED CT concept ID for interoperability (FHIR AllergyIntolerance.code).';
COMMENT ON COLUMN allergies.severity IS 'Clinical severity: mild (local reaction), moderate (systemic), severe (hospitalization risk), life-threatening (anaphylaxis).';


-- ─── Medications ──────────────────────────────────────────────────────────────
-- Active and historical medication list.
-- ONC USCDI v3: Medications required.

CREATE TABLE IF NOT EXISTS medications (
    id                      VARCHAR     PRIMARY KEY,
    patient_id              VARCHAR     NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    name                    VARCHAR(255) NOT NULL,            -- Drug brand or generic name
    ndc_code                VARCHAR(20),                     -- National Drug Code (11-digit)
    rxnorm_code             VARCHAR(20),                     -- RxNorm concept identifier
    dosage                  VARCHAR(100),                    -- e.g., "5mg", "500mg/5ml"
    frequency               VARCHAR(100),                    -- e.g., "Once daily", "BID", "TID"
    route                   VARCHAR(50),                     -- Oral | IV | IM | Topical | Inhaled | Sublingual | SQ
    status                  VARCHAR(20) NOT NULL DEFAULT 'active',
                            -- active | discontinued | on-hold | completed | entered-in-error
    prescribing_provider_id VARCHAR     REFERENCES users(id) ON DELETE SET NULL,
    start_date              VARCHAR(10),                     -- ISO date YYYY-MM-DD
    end_date                VARCHAR(10),                     -- ISO date YYYY-MM-DD (null = ongoing)
    refills                 INTEGER     NOT NULL DEFAULT 0,
    instructions            TEXT,                            -- Patient-facing instructions
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE medications IS 'Active and historical medication list. ONC USCDI v3 required.';
COMMENT ON COLUMN medications.ndc_code IS 'National Drug Code — 10/11 digit code (HIPAA standard transaction set).';
COMMENT ON COLUMN medications.rxnorm_code IS 'RxNorm CUI — NLM standard for drug interoperability (FHIR MedicationRequest).';


-- ─── Problems ─────────────────────────────────────────────────────────────────
-- Patient problem list / diagnosis list.
-- ONC USCDI v3: Problems/Diagnoses required.

CREATE TABLE IF NOT EXISTS problems (
    id              VARCHAR     PRIMARY KEY,
    patient_id      VARCHAR     NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    description     VARCHAR(500) NOT NULL,                   -- Diagnosis description
    icd10_code      VARCHAR(10),                             -- ICD-10-CM code (e.g., "I10" = HTN)
    snomed_code     VARCHAR(20),                             -- SNOMED CT concept ID
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
                    -- active | resolved | inactive | entered-in-error
    onset_date      VARCHAR(10),                             -- ISO date YYYY-MM-DD
    resolved_date   VARCHAR(10),                             -- ISO date (null if still active)
    chronic         BOOLEAN     NOT NULL DEFAULT FALSE,      -- Chronic condition flag
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE problems IS 'Problem/diagnosis list. ONC USCDI v3 required. ICD-10 required for billing.';
COMMENT ON COLUMN problems.icd10_code IS 'ICD-10-CM code — required for CMS billing (CMS-1500, UB-04) and quality reporting.';
COMMENT ON COLUMN problems.snomed_code IS 'SNOMED CT — required for FHIR Condition resource and ONC interoperability.';
COMMENT ON COLUMN problems.chronic IS 'Flags chronic conditions for care management, quality measures (HEDIS), and risk stratification.';


-- ─── Immunizations ────────────────────────────────────────────────────────────
-- Immunization administration records.
-- ONC USCDI v3: Immunizations required.

CREATE TABLE IF NOT EXISTS immunizations (
    id                  VARCHAR     PRIMARY KEY,
    patient_id          VARCHAR     NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    vaccine_name        VARCHAR(255) NOT NULL,               -- Vaccine display name
    cvx_code            VARCHAR(10),                         -- CDC CVX vaccine code
    date_administered   VARCHAR(10),                         -- ISO date YYYY-MM-DD
    dose_number         INTEGER,                             -- Dose sequence number (e.g., 1, 2, 3)
    lot_number          VARCHAR(50),                         -- Lot number for VFC/recall tracking
    site                VARCHAR(50),                         -- Left deltoid | Right deltoid | Thigh | etc.
    route               VARCHAR(20),                         -- IM | SC | ID | PO | IN
    administered_by_id  VARCHAR     REFERENCES users(id) ON DELETE SET NULL,
    vis_published_date  VARCHAR(10),                         -- VIS (Vaccine Information Statement) date
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE immunizations IS 'Immunization records. ONC USCDI v3 required. CVX codes enable immunization registry reporting (IIS).';
COMMENT ON COLUMN immunizations.cvx_code IS 'CDC CVX vaccine code — required for immunization information system (IIS) reporting.';
COMMENT ON COLUMN immunizations.lot_number IS 'Vaccine lot number — required for VFC program tracking and recall notifications.';
COMMENT ON COLUMN immunizations.vis_published_date IS 'Vaccine Information Statement published date — federally required before administration.';
