---
status: "Accepted"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0001 - Project name and anonymisation posture

## Context and problem statement

A learning monorepo documenting platform-engineering patterns for an
OpenShift Virtualization migration. The work is informed by a real
customer engagement but must be shareable as a generic reference
without leaking client, partner, sector, or geographic identifiers.

## Decision drivers

- All artifacts treated as world-readable forever (even while the
  repo is private), so anonymisation must be enforced mechanically.
- Solo maintenance budget — discipline must be carried by tooling,
  not by review.
- The categorical word list itself is a fingerprint; it cannot live
  in the public repo even as placeholders.

## Considered options

1. Use real names internally, scrub before publishing.
2. Use a generic project name and forbid real identifiers from day 0.
3. Maintain two parallel repos, one private, one scrubbed.

## Decision outcome

Chosen option: **Option 2** — the project name everywhere is
`sigma-platform`, and a layered anonymisation defence is in place
from the first commit:

- A public `.gitleaks.toml` enforces only structural rules
  (non-TEST-NET IPv4, etc.).
- A private `~/.config/sigma-platform/gitleaks-forbidden.toml`
  (sourced from a separate personal-org private repo) holds the
  actual categorical and named-entity rules. The pre-commit hook
  concatenates both.
- The `anonymisation` Claude Code skill and the
  `.github/copilot-instructions.md` rules block agents from
  generating forbidden tokens.
- The `forbidden terms list` itself is never committed, even with
  placeholders, because the placeholder slots fingerprint the sector.

### Consequences

- Good: enables the repo to go public later without retroactive
  history scrubbing.
- Good: agents (Claude Code, Copilot) self-police via skill + rules.
- Bad: requires a separately-owned private repo for the forbidden
  terms list; setting that up is Day 0 prerequisite work.
- Bad: until the private file is populated, the pre-commit hook
  enforces structural rules only and the contributor carries the
  rest.

## Validation

After Phase 0, run `git log --all -S '<each real token>'` against
the populated private list. Result must be zero hits.

## Links

- `.claude/skills/anonymisation/SKILL.md`
- `.gitleaks.toml`
- `.github/copilot-instructions.md`
