# Proposal: Design Consultation Types

## Intent

Define each Professional's agenda interval and consultation-type catalog before backend (#74) or UI (#75) delivery, resolving ambiguity around duration, money, lifecycle, booking history, and the overloaded term `Period`.

## Scope

### In Scope
- Define `Consultation Type` and the distinct `Agenda Interval` in the domain glossary and OpenSpec specifications.
- Update `docs/Origen_Documentacion.md` so RF-08, HU 3.3, and related normative text reflect the approved rules.
- Specify ownership, validation, lifecycle, atomic interval changes, snapshots, color accessibility, authorization, auditability, availability, and waiting-list compatibility.

### Out of Scope
- Backend schemas, migrations, APIs, authorization code, or production data/services (#74).
- Forms, catalog/booking interfaces, or visual implementation (#75).

## Capabilities

### New Capabilities
- `consultation-type-catalog`: Professional-owned consultation types, lifecycle, exact ARS pricing, color, interval-derived duration, booking snapshots, and downstream selection rules.
- `agenda-interval`: Professional agenda granularity and atomic adaptation of incompatible active consultation types.

### Modified Capabilities
- `default-deny-authorization`: Require explicit Professional ownership and deny unauthorized catalog changes or inactive-type selection.
- `append-only-audit`: Cover catalog lifecycle and agenda-interval change outcomes without weakening immutable audit guarantees.

## Approach

Use immutable identity and mutable fields: required name (≤32 characters; normalized duplicates allowed), exact non-floating-point ARS price (two decimals maximum, zero allowed, no business cap), `#RRGGBB` color, active state, and 1–10 interval count. Selectors distinguish duplicates by duration and price; deactivation preserves history and blocks selection. Each Professional's interval defaults to 30 minutes and accepts 5–240 in five-minute steps; effective count is `min(10, floor(240 / interval_minutes))`. Interval changes require the Professional to select a valid replacement count for every incompatible active type and confirm all replacements atomically with the interval; incompatible inactive types require the same Professional-selected valid replacement during atomic reactivation. The system must not infer, clamp, or automatically reduce any count, and a missing or invalid replacement rejects the complete operation unchanged. New bookings snapshot name, resulting minutes, and price; they store/display minutes, never counts. Existing bookings remain unchanged. Current color remains referenced after edits or deactivation, preserves contrast, and is never the sole cue.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `docs/Origen_Documentacion.md` | Modified | Glossary and normative requirements |
| `openspec/specs/` | New/Modified | Capability contracts and security/audit deltas |
| Issues #74 and #75 | Dependency | Consume this design later |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Documentation and downstream slices diverge | Medium | Make OpenSpec authoritative and cross-reference RF/HU text |
| Interval changes invalidate durations | Medium | Specify atomic adaptation and reactivation checks |
| Money precision becomes an accidental business cap | Low | Require exact finite storage without declaring its precision a product maximum |

## Rollback Plan

Revert only the normative documentation and delta-spec changes before #74/#75 consume them; no runtime or data rollback is required.

## Dependencies

- `exploration.md`; RF-07–RF-09, HU 3.1/3.3, authorization matrix `S1-09`/`OWN-01`; parent prerequisites #36 and #37.

## Success Criteria

- [ ] Specifications express every approved invariant and preserve existing bookings.
- [ ] Documentation uses `Agenda Interval` distinctly from booking-ahead `Period`.
- [ ] #74 and #75 can implement without inventing product rules.

## Tracking

- GitHub: #73 (`Diseñar las consultas`)
- GitHub: #74 (`Guardar consultas`) — backend implementation slice 1 of 2.
- GitHub: #75 (`Crear el formulario`) — UI implementation slice 2 of 2.
- Change: `design-consultation-types-73`
- Path: `openspec/changes/design-consultation-types-73/`
- Scope: Product-design and normative-documentation slice; backend #74 and UI #75 remain downstream.
