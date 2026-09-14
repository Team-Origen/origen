# Design: Synchronize the Consultation-Type Product Contract

## Technical Approach

Issue #73 is a passive, normative-documentation change. Treat the four delta specifications as the behavioral contract, then align the Spanish source-of-truth requirements, the domain-only glossary, and bidirectional GitHub/OpenSpec references. Backend #74 and UI #75 consume the resulting contract; they do not contribute production artifacts to this change.

```text
approved decisions
       ↓
four delta specs ──→ Origen_Documentacion.md
       │                       │
       └────→ CONTEXT.md       └────→ #74 / #75 contracts
                    ↓
          proposal ↔ GitHub #73
```

## Architecture Decisions

| Option | Tradeoff | Decision and rationale |
|---|---|---|
| OpenSpec deltas lead synchronization | Requires checking duplicate statements | Chosen. The deltas express testable invariants and prevent prose from silently weakening edge cases. |
| Existing requirements document leads | Familiar but currently underspecified | Rejected. RF-08 and HU 3.3 omit resolved lifecycle, interval, price, color, and atomicity rules. |
| Combine documentation with backend/UI | Earlier executable feedback but collapses #73–#75 | Rejected. Published issue boundaries make #74 responsible for persistence and #75 for presentation. |
| Infer or clamp incompatible counts | Simpler downstream interaction but changes intent silently | Rejected. Every incompatible active type requires a Professional-selected valid replacement; missing or invalid replacements reject the complete interval change. Incompatible inactive types require the same explicit adaptation during atomic reactivation. |

## Normative Product Contract

- `Consultation Type` has immutable identity and owner; mutable normalized name, exact non-negative ARS price (maximum two decimals, no business cap), `#RRGGBB` color, active state, and interval count.
- `Agenda Interval` is scheduling granularity, distinct from the future-booking `Period`; it defaults to 30 minutes and permits 5–240 minutes in five-minute steps.
- Duration is `interval_count × agenda_interval`, bounded by 1–10 intervals and 240 minutes. Existing booking snapshots of name, minutes, and price never change; color remains current and is not snapshotted.
- Deactivated types cannot be selected. Availability and waiting-list matching use immutable type identity and contiguous duration. Presentation preserves WCAG AA contrast and a non-color cue.
- Ownership is default-deny, and catalog/interval outcomes use minimized append-only audit evidence.

## Deferred Downstream Choices

#74 chooses schemas, migrations, transaction boundaries, APIs, authorization implementation, and a **finite exact** PostgreSQL monetary precision/scale. That finite representable range is a storage constraint, not a product-level price maximum, and floating point is prohibited. Database owner/migrator/runtime privileges and migration-role assumptions are therefore specified and verified in #74, not changed here. #75 chooses form, selector, adaptation-confirmation, and accessibility implementation while preserving the normative behaviors above.

## File and Traceability Changes

| Path | Action | Review target |
|---|---|---|
| `docs/Origen_Documentacion.md` | Modify | Align glossary, RF-08, HU 3.3, T1.5.1, and dependent booking text without adding implementation design. |
| `docs/CONTEXT.md` | Modify | Add implementation-free canonical definitions for Consultation Type, Agenda Interval, and booking-ahead Period. |
| `openspec/changes/design-consultation-types-73/specs/*/spec.md` | Verify | Preserve all four capability contracts, especially explicit replacement and immutable snapshots. |
| `openspec/changes/design-consultation-types-73/proposal.md` | Modify | Make explicit-replacement wording unambiguous and keep reverse references to #73 and downstream #74/#75 scopes under `Tracking`. |
| GitHub issue `#73` | Update | Add change name, repository-relative path, and product-documentation scope; retain #74/#75 as downstream slices. |
| `openspec/specs/{consultation-type-catalog,agenda-interval,default-deny-authorization,append-only-audit}/spec.md` | Archive-time sync | Merge verified deltas only after #73 verification. |

No production migrations, schemas, APIs, UI code, or implementation files belong to #73.

## Testing and Structural Verification

1. Run `gentle-ai sdd-status design-consultation-types-73`; require proposal, four specs, and design to be `done`, `nextRecommended: tasks`, and no blocked reasons. Run strict semantic OpenSpec validation if that validator is installed.
2. Review a requirement-to-document checklist covering all four specs, including missing/invalid replacement rejection and unchanged bookings.
3. Search affected prose for contradictory automatic inference/clamping, floating-point money, snapshotted color, or overloaded `Period` usage.
4. Verify the proposal and issue contain reciprocal change/path/scope references; run `git diff --check` and confirm only approved documentation/OpenSpec files changed.

## Threat Matrix

N/A — this documentation-only change introduces no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Rollout and Rollback

Merge #73 before #74/#75 consume the contract, then archive the verified deltas into main specs. Roll back by reverting the documentation and spec synchronization together; no runtime or data rollback exists. If downstream implementation has started, amend the contract forward instead of silently reverting its assumptions.

## Open Questions

None.
