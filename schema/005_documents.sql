-- ============================================================
-- Medaea EHR — Schema Migration 005: Documents
-- Version: 1.0.0 | Date: 2026-04-03 | Phase: 1
-- Tables: documents
-- ============================================================

CREATE TABLE IF NOT EXISTS documents (
    id              VARCHAR     PRIMARY KEY,
    patient_id      VARCHAR     REFERENCES patients(id) ON DELETE SET NULL,
    appointment_id  VARCHAR     REFERENCES appointments(id) ON DELETE SET NULL,
    uploaded_by     VARCHAR     REFERENCES users(id) ON DELETE SET NULL,
    file_name       VARCHAR(255),
    file_url        VARCHAR(1000),                           -- S3/GCS signed URL or storage path
    document_type   VARCHAR(100),
                    -- Lab Report | Imaging | Consent | Referral | Insurance Card
                    -- Prior Auth | CCD | CCR | Progress Note | Discharge Summary
    loinc_code      VARCHAR(20),                             -- LOINC document type code
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_documents_patient_id ON documents (patient_id);

COMMENT ON TABLE documents IS 'Clinical document repository. Files stored in cloud storage (S3/GCS), URL stored here.';
COMMENT ON COLUMN documents.loinc_code IS 'LOINC code for document type — required for FHIR DocumentReference and ONC interoperability.';
COMMENT ON COLUMN documents.file_url IS 'Cloud storage URL (S3/GCS). Should be pre-signed temporary URL in production for HIPAA BAA compliance.';
