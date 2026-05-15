---
status: "Accepted"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0003 - Private GitHub repo under personal namespace

## Context and problem statement

The original plan called for a public repo under a dedicated
`sigma-platform` GitHub organisation. Two constraints changed that:

1. The categorical anonymisation rules list itself fingerprints the
   sector (forbidding the word "bank" only makes sense if the
   engagement is with a bank). A public repo's gitleaks config is
   therefore an information leak.
2. The contributor's GitHub token does not carry `admin:org` scope,
   so creating a fresh `sigma-platform` org would require a manual
   web-UI step before any automation could land.

## Decision drivers

- Reduce blast radius of any anonymisation slip during Phase 0–2
  while patterns are still forming.
- Avoid blocking on manual org provisioning.
- Preserve the option to flip to public later, once history has been
  scrubbed and confidence is higher.

## Considered options

1. Public repo under a new `sigma-platform` org (original plan).
2. Private repo under a new `sigma-platform` org.
3. Private repo under the contributor's personal namespace (`sholaj/`).
4. Local-only, no GitHub repo.

## Decision outcome

Chosen option: **Option 3** — `sholaj/sigma-platform`, private. The
repo will be re-evaluated for public-ification after Phase 6
(policies + ADR backfill), once history is provably clean.

### Consequences

- Good: no manual GitHub org creation needed.
- Good: any anonymisation slip is contained to the contributor's
  view and the GitHub backend, not the public internet.
- Good: agents (Claude Code, Copilot, push protection) still
  enforce the same rules — the private flag is defence-in-depth,
  not the primary control.
- Bad: the original "public repo as didactic artifact" motivation is
  postponed. README still claims reference status.
- Bad: visibility flip later requires a `git log -S` audit pass.

## Validation

When considering the public flip, run the full `git log -S` audit
against the populated private forbidden-terms list. Zero hits is
required.

## Links

- ADR 0001 (anonymisation posture)
- `.github/SECURITY.md`
