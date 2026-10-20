# Repository conventions

## GitHub and OpenSpec traceability

Every implementation GitHub subissue associated with an OpenSpec change must declare the change name, repository-relative change path, and specific implementation slice or scope. One OpenSpec change may map to multiple subissues. The change's `proposal.md` must maintain reverse GitHub references under a `Tracking` section.

```md
## OpenSpec

- Change: `local-bootstrap-profile`
- Path: `openspec/changes/local-bootstrap-profile/`
- Scope: Implementation slice 1 of 6
```

## Agent skills

### Issue tracker

Issues and specs are tracked in GitHub Issues for `Team-Origen/origen`. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context domain documentation. See `docs/agents/domain.md`.
