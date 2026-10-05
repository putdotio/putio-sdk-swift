## Summary

<!-- One sentence on the outcome, then one visual aid: a screenshot or short
recording for UI (`gh pr create --attach ./file.png`, never committed), a
Mermaid diagram for a flow, a table for numbers, or a short code sample for an
API. Add one-line bullets only for risks the aid doesn't show. -->

## Validation

- [ ] `make verify`
- [ ] `make live-test` when API behavior needs real backend evidence
- [ ] Example app smoke when auth, package installation, or request flow changes

## SDK Contract

- [ ] Public API changes are intentional and documented
- [ ] Request and response models are typed at the boundary
- [ ] Error behavior includes useful recovery or retry guidance when applicable

## Risk

Call out migrations, release-flow changes, auth changes, or follow-up work.
