---
status: "Accepted"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0006 - Cost ceiling £500/month via ephemeral clusters

## Context and problem statement

ARO clusters cost ≈£2.40/hour on-demand at the smallest validated
size (3 control plane + 3 worker `Standard_D8s_v3`). The `az aro`
CLI has no `stop`/`start` — the only zero-compute state is `delete`.
Willpower alone will not keep the monthly bill below £500.

## Decision drivers

- Solo cadence, ≈6 productive hours per working day.
- The 35–45 min spin-up and 30–40 min destroy window must fit inside
  a normal workday with breaks.
- A weekend or holiday leaving a cluster running silently is a
  three-figure mistake.

## Considered options

1. Permanent cluster, accept ~£1,800/month.
2. Best-effort manual destruction at end-of-day.
3. Structural ephemerality — Terraform `destroy` at end-of-day, plus
   a scheduled GitHub Action sweep, plus an `auto-destroy=true` RG
   tag convention.

## Decision outcome

Chosen option: **Option 3**. The discipline is enforced in three places:

- `task spin:down:all` is the documented default end-of-day action.
- A daily GitHub Action (`.github/workflows/nightly-teardown.yml`,
  to be authored in Phase 1) sweeps any RG tagged `auto-destroy=true`
  whose `created` tag is older than 12 hours.
- An Azure subscription budget at £500 with alerts at 50/80/100%
  provides the back-stop.

### Consequences

- Good: at solo cadence and the one-cluster-at-a-time invariant
  (ADR 0005), monthly spend tracks ≈£310, well below the ceiling.
- Good: weekend zero-state happens automatically.
- Bad: the ~75-minute total spin-up + tear-down per working day is
  unrecoverable overhead.
- Bad: a failed `az aro create` still bills for the partial window
  — budget headroom must absorb occasional retries.

## Validation

Monthly: `az consumption usage list --start-date <month-start>
--end-date <today>` reports the actual figure. Quarterly: review
this ADR against actual spend; supersede if the assumption breaks.

## Links

- ADR 0005 (one-cluster-at-a-time)
- `.claude/skills/aro-lifecycle/SKILL.md`
