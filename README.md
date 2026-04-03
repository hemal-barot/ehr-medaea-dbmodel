# Medaea EHR — Database Model Documentation
## `ehr-medaea-dbmodel`

> **Database**: PostgreSQL 15  
> **ORM**: SQLAlchemy 2.x  
> **Schema version**: Phase 1 — April 2026  
> **Tables**: 19

---

## Overview

This repository documents the complete database schema for the Medaea EHR platform, including:

- Table definitions with all columns, types, constraints, and indexes
- Relationships and foreign key mappings
- Entity-Relationship Diagram (ERD)
- Data dictionary
- Migration history
- Future schema design (Phase 2)

---

## Repository Structure

```
ehr-medaea-dbmodel/
├── README.md                          # This file — overview and ERD
├── schema/
│   ├── 001_core_entities.sql          # organizations, users, user_organizations
│   ├── 002_patient_registry.sql       # patients
│   ├── 003_appointments.sql           # appointments
│   ├── 004_clinical_records.sql       # encounters, allergies, medications, problems, immunizations
│   ├── 005_documents.sql              # documents
│   ├── 006_audit.sql                  # audit_logs
│   └── 007_scheduling.sql             # pto_requests, availability_rules, schedule_templates,
│                                      #   rooms, room_bookings, staff_schedules, on_call_assignments
└── docs/
    ├── erd-overview.md                # Full ERD with relationships
    ├── data-dictionary.md             # All columns, types, descriptions
    └── tables/
        ├── organizations.md
        ├── users.md
        ├── user_organizations.md
        ├── patients.md
        ├── appointments.md
        ├── encounters.md
        ├── allergies.md
        ├── medications.md
        ├── problems.md
        ├── immunizations.md
        ├── audit_logs.md
        ├── documents.md
        └── scheduling.md              # pto_requests, rooms, staff_schedules, on_call_assignments
```

---

## Entity-Relationship Diagram (High Level)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          MEDAEA EHR — ERD (Phase 1)                      │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  organizations  │     │   user_organizations  │     │     users       │
│─────────────────│     │──────────────────────│     │─────────────────│
│ id (PK)         │◀────│ organization_id (FK)  │────▶│ id (PK)         │
│ name            │     │ user_id (FK)          │     │ email (UQ,IDX)  │
│ org_type        │     │ role                  │     │ hashed_password │
│ address         │     │ department            │     │ first_name      │
│ city            │     │ permissions (JSON)    │     │ last_name       │
│ state           │     └──────────────────────┘     │ role            │
│ zip             │                                   │ specialty       │
│ npi             │                                   │ npi             │
│ tax_id          │                                   │ mfa_enabled     │
│ phone           │                                   │ is_verified     │
│ is_active       │                                   │ hipaa_consent   │
│ created_at      │                                   │ created_at      │
└────────┬────────┘                                   └────────┬────────┘
         │                                                     │
         │ 1:N                                                 │ 1:N
         ▼                                                     ▼
┌─────────────────┐                                  ┌─────────────────┐
│    patients     │                                  │  appointments   │
│─────────────────│◀─────────────────────────────────│─────────────────│
│ id (PK)         │     patient_id FK                │ id (PK)         │
│ first_name      │                                  │ patient_id (FK) │
│ last_name       │                                  │ provider_id(FK) │
│ email           │                                  │ start_time      │
│ phone           │                                  │ end_time        │
│ date_of_birth   │                                  │ visit_type      │
│ gender          │                                  │ status          │
│ address         │                                  │ room            │
│ race            │                                  │ reason          │
│ ethnicity       │                                  │ location_type   │
│ preferred_lang  │                                  │ organization_id │
│ mrn (MRN)       │                                  │ created_at      │
│ status          │                                  └────────┬────────┘
│ organization_id │                                           │
│ created_at      │                                           │ 1:1
└────────┬────────┘                                           ▼
         │                                           ┌─────────────────┐
         │ 1:N (5 clinical sub-tables)               │   encounters    │
         │                                           │─────────────────│
    ┌────┴──────────────────────────────┐            │ id (PK)         │
    │              │         │          │            │ patient_id (FK) │
    ▼              ▼         ▼          ▼            │ provider_id(FK) │
┌─────────┐ ┌──────────┐ ┌────────┐ ┌──────────────┐│ appointment_id  │
│allergies│ │medication│ │problem │ │immunizations ││ chief_complaint  │
│─────────│ │──────────│ │────────│ │──────────────││ subjective (S)  │
│allergen │ │name      │ │descrip │ │vaccine_name  ││ objective (O)   │
│reaction │ │ndc_code  │ │icd10   │ │cvx_code      ││ assessment (A)  │
│severity │ │rxnorm    │ │snomed  │ │date_admin    ││ plan (P)        │
│status   │ │dosage    │ │status  │ │dose_number   ││ status          │
│snomed   │ │frequency │ │onset   │ │lot_number    ││ encounter_date  │
│onset    │ │route     │ │chronic │ │site/route    │└─────────────────┘
└─────────┘ │status    │ └────────┘ └──────────────┘
            │start/end │
            │refills   │           ┌─────────────────┐
            └──────────┘           │   audit_logs    │
                                   │─────────────────│
                                   │ user_id (FK)    │
                                   │ action          │
                                   │ resource_type   │
                                   │ resource_id     │
                                   │ ip_address      │
                                   │ phi_accessed    │
                                   └─────────────────┘
```

---

## Scheduling Domain ERD

```
┌──────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
│  schedule_       │     │   staff_schedules   │     │on_call_assign.. │
│  templates       │     │─────────────────────│     │─────────────────│
│──────────────────│     │ user_id (FK)         │     │ user_id (FK)    │
│ name             │     │ organization_id      │     │ backup_user_id  │
│ badge            │     │ mon/tue/wed/thu/fri  │     │ period_label    │
│ status           │     │ sat/sun              │     │ start_at        │
│ days/hours       │     │ status               │     │ end_at          │
│ types/applied_to │     │ effective_from       │     │ status          │
└──────────────────┘     └─────────────────────┘     └─────────────────┘

┌──────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
│  pto_requests    │     │  availability_rules │     │     rooms       │
│──────────────────│     │─────────────────────│     │─────────────────│
│ user_id (FK)     │     │ name                │     │ id (PK)         │
│ organization_id  │     │ type (Buffer/Break) │     │ name            │
│ type (PTO/Sick)  │     │ priority            │     │ type            │
│ status           │     │ description         │     │ status          │
│ date_from/to     │     │ applies_to          │     │ icon            │
│ duration         │     │ conditions          │     └────────┬────────┘
│ coverage_provider│     │ enabled             │              │ 1:N
│ reason           │     └─────────────────────┘              ▼
└──────────────────┘                              ┌─────────────────────┐
                                                  │   room_bookings     │
                                                  │─────────────────────│
                                                  │ room_id (FK)        │
                                                  │ appointment_id (FK) │
                                                  │ patient_name        │
                                                  │ doctor_name         │
                                                  │ booking_date        │
                                                  │ start_hour/min      │
                                                  │ duration_min        │
                                                  └─────────────────────┘
```

---

## Tables Summary

| # | Table | Rows (Est.) | Domain | Key Relationship |
|---|---|---|---|---|
| 1 | `organizations` | Low | Core | Root entity |
| 2 | `users` | Low-Med | Core | Linked to orgs via join table |
| 3 | `user_organizations` | Low-Med | Core | M:M users↔orgs |
| 4 | `patients` | High | Clinical | Belongs to org + primary provider |
| 5 | `appointments` | High | Scheduling | patient + provider + org |
| 6 | `encounters` | High | Clinical | patient + provider + optional appt |
| 7 | `allergies` | Med | Charting | Belongs to patient |
| 8 | `medications` | Med | Charting | Belongs to patient |
| 9 | `problems` | Med | Charting | Belongs to patient (ICD-10) |
| 10 | `immunizations` | Med | Charting | Belongs to patient (CVX) |
| 11 | `audit_logs` | Very High | HIPAA | Belongs to user |
| 12 | `documents` | Med | Documents | patient + appointment + uploader |
| 13 | `pto_requests` | Low | Scheduling | Belongs to user |
| 14 | `availability_rules` | Low | Scheduling | Belongs to org |
| 15 | `schedule_templates` | Low | Scheduling | Belongs to org |
| 16 | `rooms` | Low | Scheduling | Belongs to org |
| 17 | `room_bookings` | Med | Scheduling | room + optional appointment |
| 18 | `staff_schedules` | Low | Scheduling | user + org |
| 19 | `on_call_assignments` | Low | Scheduling | user + backup user + org |

---

## Data Types

| SQLAlchemy | PostgreSQL | Usage |
|---|---|---|
| `String` | `VARCHAR` | IDs, names, codes |
| `Text` | `TEXT` | Long content (notes, SOAP, descriptions) |
| `Boolean` | `BOOLEAN` | Flags (is_active, mfa_enabled, etc.) |
| `Integer` | `INTEGER` | Duration, dose numbers, counts |
| `DateTime(timezone=True)` | `TIMESTAMPTZ` | All timestamps — UTC |
| `JSON` | `JSONB` | permissions, mfa_backup_codes |

---

## ID Strategy

All primary keys use **UUID v4** strings generated in Python:
```python
id = str(uuid.uuid4())  # e.g., "550e8400-e29b-41d4-a716-446655440000"
```

Benefits:
- No sequential ID exposure (security)
- Safe for distributed systems
- No auto-increment conflicts in migrations

---

## Timestamp Convention

All tables include `created_at` as `DateTime(timezone=True)` defaulting to `datetime.now(timezone.utc)`.

Future tables will add `updated_at` with auto-update trigger.

---

## Indexes

| Table | Indexed Columns |
|---|---|
| `users` | `email` (unique), `email_verification_token`, `password_reset_token` |
| `pto_requests` | `user_id`, `organization_id` |
| `availability_rules` | `organization_id` |
| `schedule_templates` | `organization_id` |
| `rooms` | `organization_id` |
| `room_bookings` | `room_id` |
| `staff_schedules` | `user_id` |
| `on_call_assignments` | `user_id` |

---

## Related Repositories

| Repo | Description |
|---|---|
| [ehr-medaea-backend](https://github.com/hemal-barot/ehr-medaea-backend) | Source code (models.py) |
| [ehr-medaea-backend-apis](https://github.com/hemal-barot/ehr-medaea-backend-apis) | API documentation |
| [ehr-medaea-documentations](https://github.com/hemal-barot/ehr-medaea-documentations) | Compliance + progress |
