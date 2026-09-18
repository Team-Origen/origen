# Repository conventions

## GitHub and OpenSpec traceability

Every implementation GitHub subissue associated with an OpenSpec change must declare the change name, repository-relative change path, and specific implementation slice or scope. One OpenSpec change may map to multiple subissues. The change's `proposal.md` must maintain reverse GitHub references under a `Tracking` section.

```md
## OpenSpec

- Change: `local-bootstrap-profile`
- Path: `openspec/changes/local-bootstrap-profile/`
- Scope: Implementation slice 1 of 6
```
