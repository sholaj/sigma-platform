---
status: "Accepted"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0007 - No server-side branch protection on `main`

## Context and problem statement

The Day 2 workflows (`lint`, `secret-scan`, `schema-validate`) are
merged and run on every PR + push to `main`. ADR 0003 records that
the repo is private under a personal-account free tier
(`sholaj/sigma-platform`). When attempting to apply the §2.3 branch
protection rules — required status checks, required signatures,
required PRs — the GitHub API returned 403 against both the
`/branches/*/protection` and `/rulesets` endpoints with the message
"Upgrade to GitHub Pro or make this repository public to enable
this feature."

GitHub gates BOTH branch protection AND the newer Rulesets API
behind Pro (or public visibility) for personal-account private
repos.

## Decision drivers

- Solo contributor, low contention; no one but the operator can
  force-merge anyway.
- Local pre-commit hooks already block bad content before it leaves
  the workstation; CI workflows already run on PRs and surface
  failures even though they cannot block merges.
- The £500/month Azure budget dominates the cost picture; a $4/month
  GitHub Pro upgrade is rounding error against that.
- ADR 0003 defers the public flip until after Phase 6's
  anonymisation audit; that path is not available today.

## Considered options

1. **Upgrade to GitHub Pro** ($4/month). Unlocks branch protection,
   required signatures, rulesets, GHAS secret scanning push
   protection on private repos.
2. **Accept no server-side gating**; rely on local pre-commit hooks
   plus CI surfacing for now.
3. **Flip the repo public** to get free protection + GHAS. Premature;
   the anonymisation audit (ADR 0001) is not complete.

## Decision outcome

Chosen option: **Option 2** — accept no server-side gating today.

This is a pragmatic trade for a learning project. The discipline
needed is "every change goes through a PR even though I could push
direct"; with one contributor and the existing CI surfacing failures
on every PR, the cost of an occasional discipline slip is bounded.

When the operator's appetite or scale changes (a second contributor,
the public flip succeeds, or a real incident occurs), reopen this
ADR and either supersede with "Upgraded to Pro" or "Repo flipped
public".

### Consequences

- Good: zero monthly cost change.
- Good: the workflows already provide signal; failures are visible
  on PR pages even without blocking merges.
- Good: local `commit.gpgsign true` still signs every commit
  (`Good signature, ed25519 key C1B77C8EB9EB1248`); GitHub just
  won't refuse unsigned ones server-side.
- Bad: a tired-late-night `git push origin main` with a broken
  commit can land directly on `main` without CI gate.
- Bad: required-status-checks contexts (`lint`, `secret-scan`,
  `schema-validate`) exist as informational checks only.
- Bad: signed-commit enforcement is local-only — if signing config
  drifts on a future workstation, GitHub will not catch it.

## Validation

Quarterly: ask whether the discipline has been kept or whether a
direct-push slip has occurred. If yes to a slip, supersede this ADR
with Option 1 (upgrade to Pro). If the public flip is on the
horizon, supersede with Option 3.

## Links

- ADR 0003 (private-repo personal-namespace posture)
- Tracking issue #1 (Day 0 / Day 2 / signing follow-ups)
- GitHub docs: https://docs.github.com/rest/branches/branch-protection
