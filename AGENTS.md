# Repository conventions

## GitHub and OpenSpec traceability

Every implementation GitHub subissue associated with an OpenSpec change must declare the change name, repository-relative change path, and specific implementation slice or scope. One OpenSpec change may map to multiple subissues. The change's `proposal.md` must maintain reverse GitHub references under a `Tracking` section.

```md
## OpenSpec

- Change: `local-bootstrap-profile`
- Path: `openspec/changes/local-bootstrap-profile/`
- Scope: Implementation slice 1 of 6
```

## Frontend URL conventions

Before creating or modifying frontend routes, links, forms, or redirects, read and follow the canonical [URL conventions and migration plan](docs/navigation/URL_CONVENTIONS.md). Use its Spanish, role-first structure and explicit exceptions. Preserve existing filter behavior, query parameters, and authorization; do not add URL filters or redesign access controls as part of a route rename. If a case does not fit the documented convention or depends on an unresolved decision, flag it before introducing another structure. Planned destinations do not authorize implementing pending features. Navbar planning is a separate step.

## Agent skills

### Issue tracker

Issues and specs are tracked in GitHub Issues for `Team-Origen/origen`. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context domain documentation. See `docs/agents/domain.md`.
