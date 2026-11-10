# #379 — Full lifecycle integration coverage

Refs #379. Parent #285. OpenSpec `health-center-beta-core`, integration slice.

## Verified behavior

All four real LiveView scenarios exercise persisted booking operations, not
appointment-row fixtures. Accounts, identities and availability are test setup.

| Flow | Observed effects |
| --- | --- |
| Patient → Professional | Navbar access, requested booking, professional acceptance, persisted confirmation and patient history reload. |
| Professional cancellation | Required reason, rejected submission leaves state/history/audit unchanged, origin and reason visible to the patient. |
| Replacement | Separate date, hour and consultation-type changes cancel the original and create a new booking; original history is retained. |
| Secretary operations | Bookings across agendas, reason-required cancellation, attendance and absence, patient reload and persisted origins. |
| Expiry and privacy | Public expiry sweep releases occupancy and retains history; expired attendance rejected; patient attendance rejected; role histories remain scoped. |

## Verification

- Independent first slice: 1/1 passed after finite canonical helper mappings.
- Focused eleven-file command: 62/62 passed (four new and 58 complementary tests).
- Full suite after the helper fix: 1080 passed, 32 skipped, 8 excluded;
  seed 0, exit 0. Format and compile with warnings as errors passed.
- Existing expiry-worker tests run in the full suite; the new UI expiry case
  uses the public sweep and does not claim timer execution.
- No browser/cloud verification, excluded PostgreSQL security coverage,
  final human acceptance, parent closure or automatic issue closure is claimed.

## Review and delivery

Review the four tests and complete helper first. The next chain slice records
OpenSpec reverse tracking, the complete failure chronology and delivery state.
No production behavior, dependencies, routes or permission contracts changed.
No merge is authorized.
