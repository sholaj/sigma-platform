---
status: "Accepted"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0005 - One ARO cluster at a time; kind as the ACM spoke

## Context and problem statement

The original plan ran two ARO clusters (hub + virt) concurrently to
exercise ACM multi-cluster patterns. With a single contributor on a
£500/month budget, two concurrent clusters consume the entire
budget within working hours, leaving no room for retries or weekend
learning.

## Decision drivers

- Cost ceiling £500/month (ADR 0006).
- Solo cadence — only one cluster is in active use at any given
  moment anyway.
- ACM multi-cluster patterns need a spoke, but the spoke does not
  need to be a paid Azure cluster.

## Considered options

1. Two ARO clusters (hub + virt), as originally drafted.
2. One ARO cluster (hub-or-virt mode), no multi-cluster exercise.
3. One ARO cluster + a local kind cluster imported into ACM as the
   spoke.

## Decision outcome

Chosen option: **Option 3**. The invariant is enforced by
`task aro:assert-none-running`, which fails any `task spin:up:*` if
an ARO cluster is already provisioned. Hub-day and virt-day are
alternating modes, not parallel deployments.

### Consequences

- Good: ≈£310/month at solo cadence, comfortable headroom on the
  £500 ceiling.
- Good: multi-cluster ACM patterns exercised fully (the
  `ManagedCluster` CRD does not care that the spoke is on the
  workstation).
- Bad: hub-day and virt-day cannot be combined in a single session
  — switching modes is a 90-minute round-trip.
- Bad: networking between hub and spoke must work over the public
  internet (kind agent → ARO hub API server), which exercises a
  topology slightly different from the production hub-spoke design.

## Validation

After Phase 3, an ApplicationSet with a `Cluster` generator deploys
a sample workload to both `local-cluster` (the ARO hub) and the
imported kind spoke. Both deployments reach `Healthy` and `Synced`.

## Links

- ADR 0006 (cost ceiling)
- `.claude/skills/aro-lifecycle/SKILL.md`
- `scripts/tasks/aro.yml` (`assert-none-running`)
