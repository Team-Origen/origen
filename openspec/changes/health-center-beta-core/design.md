# Design: Health-center beta core

## Purpose

This document sets specification boundaries and reconciliation rules. It does not select implementation modules, database migrations, hosting, branding, assignments, or estimates.

## Domain vocabulary

| Term | Meaning for this change |
|---|---|
| Patient | The single identity identified by DNI, with optional personal-access email. A patient can exist without an account/email. |
| Personal access | A patient’s passwordless magic-link access to only their own appointments and read-only identity data. |
| Appointment request | A booking in `requested` state under manual approval. It occupies the slot and establishes the Professional–Patient relationship. |
| Confirmed appointment | An appointment approved directly or by a Professional. It is not an attendance result. |
| Expired request | An unresolved request at its start time; preserved in history, not automatically confirmed, absent, or fined. |
| Payment correction | Reversal of an incorrect paid mark back to pending. It is not a recorded refund. |

## Authorization boundary

All new operations remain default-deny until explicitly represented in the authorization matrix. Role visibility is intentionally narrow:

- Patients: only their own appointments, payment status, final price, and read-only identity data.
- Professionals: their settings, appointments, and only patients related through a completed request or appointment; no other-professional activity.
- Secretary: centre patient list and all professional agendas; never professional settings or approval/rejection of pending requests.
- Administrator: only Professional/Secretary account lifecycle; no implicit operational or financial access.

## State boundary

The lifecycle is `requested`, `confirmed`, `expired`, `cancelled`, `attended`, or `no_show`. `requested` occupies availability. Cancellation and rejection free availability. A direct reschedule does not exist: a caller cancels then creates another appointment.

An implementation may retain or migrate existing storage states only if it produces these observable outcomes; it must not expose legacy D-1, phone-verification, fine, or confirmation behavior contrary to the specifications.

## Independent operational boundary

Cloud availability is required for beta delivery but provider/budget are unresolved. Product identity is required early in implementation but name/logo/palette/type remain unresolved. Both are independent of the domain requirements and must be represented as explicit dependency records in later work, never filled in by defaults from the current repository.

## Future implementation obligations

A later approved implementation plan must define:

- authorization rows and backend-denial tests for every new sensitive operation;
- migration and rollback mechanics that preserve historical identity, appointment, payment, and audit records;
- public-interface tests for each required observable effect, including no state change on rejected input;
- a separate beta delivery-acceptance artifact for manual, real-flow data, functional/permission verification, cloud acceptance, and stabilization;
- a glossary update resolving the historical `Confirmed` ambiguity.
