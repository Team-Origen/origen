# #379 — Slice 1 evidence

## Scope

This slice isolates the first real Patient → Professional integration flow.
The test copy keeps the current module/setup, the complete first scenario, the
private `audit_count/2` helper, and the complete helper dependency.

## Covered behavior

- Patient reaches `Mis turnos` and `Reservar turno` through the navbar.
- Patient creates a requested appointment through the real booking LiveView.
- Professional reaches the agenda through the navbar and sees the request.
- Professional resolves the request through the LiveView action.
- The appointment persists as `confirmed` and receives one successful audit.
- Patient reloads the history and sees the confirmed appointment.
- The public copy confirms cancellation before start is `sin multa`; no D-1 text
  is exposed.

## Verification reference

The final tested source snapshot is `finalintegration.exs`; its SHA-256 is
`68fec4a991fcef59678446176f734e8f2091e254702f14c4238391f98cac3874`.
The full focused snapshot contains four authored scenarios; this first slice
contains one. The independent first-slice check passed 1/1 after the helper
used finite canonical configuration mappings. The final focused run passed
62/62; the subsequent full suite passed 1080 tests, with 32 skipped and 8
excluded, seed 0, exit 0. Format and warnings-as-errors compilation passed.
No final human acceptance, cloud/browser/security coverage, #285 closure,
or automatic closing reference is claimed.
