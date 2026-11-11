# Issue #306 backend delivery chain

Draft integration tracker for the approved `feature-branch-chain` delivery. Do not merge this tracker until the child PRs have been reviewed and integrated. Refs [#306](https://github.com/Team-Origen/origen/issues/306); parent #280 and integration #308 remain outside this delivery.

## Review order

```text
develop
  <- feat/306-patient-self-booking              (draft tracker, this document)
       <- feat/306-patient-calendar-availability (calendar slice)
            <- feat/306-patient-booking-backend (atomic booking slice)
```

| Slice | Base branch | Scope | Authored lines |
| --- | --- | --- | --- |
| Tracker | `develop` | Delivery map only; no application changes | Documentation only |
| Calendar | `feat/306-patient-self-booking` | Persisted occupancy and direct calendar regressions | 147 |
| Backend | `feat/306-patient-calendar-availability` | Atomic patient booking, compatibility, tests and evidence | 1260 |

The backend unit exceeds the advisory 400-line budget. Its transaction, identity/catalog guards, concurrent collision test and rollback regressions are one coherent behavior unit. Keep tests and evidence with the behavior; do not split by file type. The selected chain isolates the independently reviewable calendar first.

## Evidence and approval

- Human acceptance and issue closure: [#306 closing record](https://github.com/Team-Origen/origen/issues/306#issuecomment-6618692701). Publication was authorized afterward; this tracker does not imply merge authorization.
- Calendar commit: `1e177d681b121f6451c3f17d95b71f43c90baf9e`; calendar native review `review-848188208626b04f` approved and acknowledged.
- Final backend head: `3d0a5e72f6addf7db1cedc2d2bdb194f048a6b89`, including compatibility commit `135406c7ab7fa86a0b304f3815a540724dc5fae1`.
- Final backend native review `review-686f76ae1efae24d` approved and acknowledged for target `sha256:1fa8abdfe9d82fc386b46b5bc64c1753342e6746a43d70a0d7f716cfa81b79f4`. Advisory `R2-approval-mode-fallback` is informational and did not open a correction.
- Recorded final full suite: 884 passed, 32 skipped, 8 excluded. Independent compatibility verification: 24 passed, zero failures/skips/exclusions. Formatter, whitespace and Dialyzer passed; Dialyzer skipped 54 configured warnings. These are observed local results, not a claim that remote CI has passed.
- Detailed backend evidence: `docs/sprints/evidence/306-patient-self-booking-backend.md` on the backend branch.

## Boundaries

The existing reviewed branches start from `5676e4e0ef87d43a34312cac565af89da5d1c04a`. At publication preparation, remote `develop` was `341901f637fd28156a832ccf801a35bb8dbdf559`. No history rewrite or automatic merge is included; check current mergeability and CI before integration.

No frontend delivery, integrated C10/C12 acceptance, #280 closure, #308 execution, dependency update or schema change is included. The backend reuses `Booking.persist_appointment/2`; the deprecated date helper does not control autonomous booking. Tracker-only changes require structural review, not a behavior RED test. Merge and deployment remain separate maintainer decisions.
