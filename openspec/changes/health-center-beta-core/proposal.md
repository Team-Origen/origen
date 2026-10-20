# Proposal: Health-center beta core

## Intent

Specify the approved functional core for an academic appointment-management beta for one configurable health centre. The beta reuses Origen but is not tied to a particular institution. This change publishes specification only: it creates no implementation ticket, source-code change, migration, deployment, or team assignment.

The implementation order is a priority sequence, not a beta scope cut. Every approved capability remains in scope for the beta.

## Confirmed scope

The beta covers:

1. Passwordless patient access, assisted patient registration, identity maintenance, staff accounts, and professional configuration.
2. Appointment creation by patient, professional, and secretary using real availability and privacy boundaries.
3. Automatic/manual approval, rejection, expiry, cancellation, attendance, absence, and non-clinical history.
4. Patient/email maintenance, one-off agenda blocks, and staff-account deactivation/reactivation.
5. One full payment per appointment and period summaries by appointment date.
6. Final navigation/message/state consistency. An optional professional photo is the last functional priority, not an access or booking prerequisite.

## Product boundaries

- The centre has one deployment and one shared operational scope; this beta does not introduce multi-centre tenancy or per-centre branding.
- Patients reserve only for themselves. The system does not support dependants or family booking.
- Patient access uses a magic link sent to a linked email, not a password or mandatory phone verification.
- Assisted registration requires name, surname, DNI, birth date, and phone. It may omit email and does not create personal access automatically.
- A patient is unique by DNI. Staff search before creating, may register if absent, and can later link or replace an email without changing the patient or their appointment history.
- The Administrator manages only Professional and Secretary accounts. It has no implicit patient, appointment, payment, or professional-settings authority.

## Explicit pending decisions

| Pending decision | Current rule | What it blocks |
|---|---|---|
| Product identity | Name, logo, palette, and typography remain undecided. Do not retain or replace Origen branding by assumption. | Brand assets and final visual-coherence work only. |
| Hosting and budget | Cloud deployment is required; provider, cost, and teacher conditions remain undecided. | Concrete deployment configuration and operational acceptance only. |

Neither pending decision blocks the independent domain specification in this change.

## Week-16 delivery boundary

A user manual, fictitious persistent data entered through real product flows, functional and permission checks, cloud availability, and the two-week stabilization window remain required beta outcomes. They are intentionally outside this core domain specification and require a separate delivery-acceptance artifact. This decision neither excludes nor defers them from the beta.

## Non-goals

- Implementation work, code, migrations, deployment, test execution, implementation tickets, assignment, estimates, or commits.
- WhatsApp; mandatory phone verification for booking; clinical notes, history, or results; fines; direct rescheduling; payment receipts, partial payments, patient credit/current account, refunds, or automatic payment transfer.
- Family/dependant booking, waiting lists, advanced reporting, global/centre comparisons, patient self-editing or internal change-request forms, medical credential verification, credential-type catalogues, per-centre branding, and performance testing.

## Current-code reconciliation

The current booking implementation already has useful foundations: immutable appointment snapshots, database-backed overlap constraints, append-only audit insertion, and a professional–patient relation. It does not prove the approved beta behavior. In particular, it currently requires verified patient phones, retains historical D-1 behavior, does not create a professional relation for `requested`, and requires a secretary schedule-agreement input. The published specifications supersede those rules for this beta; later implementation must change them deliberately and test the resulting behavior.

The existing glossary also defines `Confirmed` as attendance confirmation, while the approved beta uses it as an already-approved appointment state. The change's appointment-lifecycle specification is canonical for this beta; a future implementation/documentation slice must reconcile the glossary rather than silently preserve both meanings.

## Security and data impact

Identity, magic-link invalidation, role authorization, cross-professional privacy, and financial corrections are security-sensitive. Future implementation must extend the default-deny authorization matrix and observable audit boundaries before exposing each operation. Data and state-model migration risk is medium to high; migration/rollback mechanics are design work, not a product decision made by this proposal. Historical appointments, identity, and correction records must not be silently discarded.

## Tracking

- OpenSpec change: `health-center-beta-core`
- Path: `openspec/changes/health-center-beta-core/`
- Parent Wayfinder map: [#266](https://github.com/Team-Origen/origen/issues/266)
- Implementation subissues:
  - [#276 — Register an absent patient from Secretary](https://github.com/Team-Origen/origen/issues/276)
  - [#277 — Link patient access by magic link](https://github.com/Team-Origen/origen/issues/277)
  - [#278 — Configure a booking-ready professional profile](https://github.com/Team-Origen/origen/issues/278)
  - [#279 — Manage the internal-account lifecycle](https://github.com/Team-Origen/origen/issues/279)
  - [#280 — Book an own appointment as Patient](https://github.com/Team-Origen/origen/issues/280)
  - [#281 — Schedule an existing patient from Secretary](https://github.com/Team-Origen/origen/issues/281)
  - [#282 — Schedule an existing patient from Professional with privacy](https://github.com/Team-Origen/origen/issues/282)
  - [#283 — Register and schedule an absent patient from Professional](https://github.com/Team-Origen/origen/issues/283)
  - [#284 — Resolve manual-approval requests](https://github.com/Team-Origen/origen/issues/284)
  - [#285 — Complete the appointment operational lifecycle](https://github.com/Team-Origen/origen/issues/285)
  - [#286 — Block one-off agenda ranges](https://github.com/Team-Origen/origen/issues/286)
  - [#287 — Record and correct simple payments](https://github.com/Team-Origen/origen/issues/287)
  - [#288 — View a period summary by appointment date](https://github.com/Team-Origen/origen/issues/288)
  - [#289 — Unify core navigation and messages](https://github.com/Team-Origen/origen/issues/289)
  - [#290 — Define the beta-delivery acceptance artifact](https://github.com/Team-Origen/origen/issues/290)
  - [#291 — Apply approved visual identity](https://github.com/Team-Origen/origen/issues/291), blocked by #274
  - [#292 — Complete cloud-hosting acceptance](https://github.com/Team-Origen/origen/issues/292), blocked by #275

### Sprint 3 work breakdown

All items below belong to Sprint 3 (milestone 5). Integration is gated by every sibling and every blocker of its functional parent; parent dependencies remain unchanged. The two children of #290 define and verify the acceptance artifact, not final beta delivery.

- Parent [#276](https://github.com/Team-Origen/origen/issues/276): [Contract #293](https://github.com/Team-Origen/origen/issues/293); [Backend #294](https://github.com/Team-Origen/origen/issues/294); [Frontend #295](https://github.com/Team-Origen/origen/issues/295); [Integration and verification #296](https://github.com/Team-Origen/origen/issues/296).
- Parent [#277](https://github.com/Team-Origen/origen/issues/277): [Contract #297](https://github.com/Team-Origen/origen/issues/297); [Backend #298](https://github.com/Team-Origen/origen/issues/298); [Frontend #299](https://github.com/Team-Origen/origen/issues/299); [Integration and verification #300](https://github.com/Team-Origen/origen/issues/300).
- Parent [#278](https://github.com/Team-Origen/origen/issues/278): [Contract #301](https://github.com/Team-Origen/origen/issues/301); [Backend #302](https://github.com/Team-Origen/origen/issues/302); [Frontend #303](https://github.com/Team-Origen/origen/issues/303); [Integration and verification #304](https://github.com/Team-Origen/origen/issues/304).
- Parent [#280](https://github.com/Team-Origen/origen/issues/280): [Contract #305](https://github.com/Team-Origen/origen/issues/305); [Backend #306](https://github.com/Team-Origen/origen/issues/306); [Frontend #307](https://github.com/Team-Origen/origen/issues/307); [Integration and verification #308](https://github.com/Team-Origen/origen/issues/308).
- Parent [#281](https://github.com/Team-Origen/origen/issues/281): [Contract #309](https://github.com/Team-Origen/origen/issues/309); [Backend #310](https://github.com/Team-Origen/origen/issues/310); [Frontend #311](https://github.com/Team-Origen/origen/issues/311); [Integration and verification #312](https://github.com/Team-Origen/origen/issues/312).
- Parent [#282](https://github.com/Team-Origen/origen/issues/282): [Contract #313](https://github.com/Team-Origen/origen/issues/313); [Backend #314](https://github.com/Team-Origen/origen/issues/314); [Frontend #315](https://github.com/Team-Origen/origen/issues/315); [Integration and verification #316](https://github.com/Team-Origen/origen/issues/316).
- Parent [#283](https://github.com/Team-Origen/origen/issues/283): [Contract #317](https://github.com/Team-Origen/origen/issues/317); [Backend #318](https://github.com/Team-Origen/origen/issues/318); [Frontend #319](https://github.com/Team-Origen/origen/issues/319); [Integration and verification #320](https://github.com/Team-Origen/origen/issues/320).
- Parent [#284](https://github.com/Team-Origen/origen/issues/284): [Contract #321](https://github.com/Team-Origen/origen/issues/321); [Backend #322](https://github.com/Team-Origen/origen/issues/322); [Frontend #323](https://github.com/Team-Origen/origen/issues/323); [Integration and verification #324](https://github.com/Team-Origen/origen/issues/324).
- Parent [#290](https://github.com/Team-Origen/origen/issues/290): [Contract #325](https://github.com/Team-Origen/origen/issues/325); [Integration and verification #326](https://github.com/Team-Origen/origen/issues/326).

## Success criteria

- [ ] All approved beta core rules from Wayfinder #266 and historical resolutions #267–#273 are represented normatively.
- [ ] Week-16 scope and exclusions are preserved, while delivery acceptance stays outside this core artifact.
- [ ] Visual identity and concrete hosting remain visibly unresolved and only block dependent work.
- [ ] Existing incompatible booking rules are identified without claiming implementation or test evidence.
- [ ] No implementation ticket, code change, migration, deployment, or assignment is created by this change.
