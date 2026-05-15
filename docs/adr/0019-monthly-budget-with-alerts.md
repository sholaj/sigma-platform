---
status: "Accepted"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0019 - Single subscription, monthly £500 budget with 50/80/100% alerts

## Context and problem statement

The cost ceiling is £500/month (ADR 0006). The subscription is
Pay-As-You-Go (sub name: `Azure subscription 1`, tenant `16dd244e…`).
Azure budgets generate alerts but do NOT hard-cap spending on PAYG —
a tired-late-night missed teardown of an ARO cluster can run for a
weekend and dent the budget by £100+ before the next alert fires.

## Decision drivers

- A single PAYG sub keeps cost visibility simple; multi-sub adds
  audit overhead without obvious benefit at this scale.
- 50/80/100% alert thresholds give early/mid/late warning before
  the ceiling is crossed.
- Alerts are necessary but not sufficient: the structural defences
  are ADR 0005 (one cluster at a time) plus the nightly-teardown
  GitHub Action sweeping `auto-destroy=true` RGs.

## Considered options

1. **Single sub + monthly budget + 50/80/100% alerts + structural
   nightly teardown.**
2. Multi-subscription with role-based isolation — overkill for solo.
3. Budget alerts only, no nightly teardown — relies on willpower.
4. Pre-paid commitment (Reserved Instances / Savings Plan) — wrong
   for ephemeral usage where clusters are destroyed nightly.

## Decision outcome

Chosen option: **Option 1**, implemented as:

- `azurerm_consumption_budget_subscription.monthly` at subscription
  scope, £500/month, three alert notifications at 50/80/100% actual
  spend.
- `time_period.start_date` set to the first of the current month via
  the `budget_start_date` variable, with `lifecycle.ignore_changes =
  [time_period]` so plans stay stable across month boundaries.
- Alert email list passed via the `alert_emails` variable (set to
  your real address; not committed — lives in
  `terraform.tfvars`, gitignored).

The nightly-teardown GitHub Action that complements this is authored
in Phase 1 follow-up as `.github/workflows/nightly-teardown.yml`,
gated on the OIDC federated credential set up alongside this ADR.

### Consequences

- Good: visible burn rate at three thresholds; first alert fires
  ≈£60 of weekend over-run before significant damage.
- Good: alert emails route to a real human (the contributor).
- Good: subscription-scope makes cost-allocation simple — every
  spend on the sub counts toward the ceiling.
- Bad: alerts are informational on PAYG. A missed Friday teardown
  still costs whatever the cluster bills until Monday. **The
  nightly teardown workflow is the actual cap.**
- Bad: a £500 ceiling is soft. A pathological week (two failed
  `az aro create` attempts + a weekend over-run) could exceed it.

## Validation

- [ ] After first apply, `az consumption budget list --query
      "[?name=='sigma-platform-monthly']" -o table` returns the
      budget.
- [ ] Trigger a synthetic test by lowering the threshold to 1%
      temporarily and verifying the alert email arrives within
      ~24h (Azure's evaluation cadence).
- [ ] Quarterly: compare actual spend against £500 ceiling; if
      consistently 50–80%, leave the ceiling; if persistently
      90%+, supersede this ADR with a higher number plus a
      justification.

## Links

- ADR 0006 (cost ceiling — the structural decision this implements)
- `infra/terraform/envs/shared/main.tf` (budget resource)
- `scripts/setup/azure-bootstrap.md` (apply + verification)
