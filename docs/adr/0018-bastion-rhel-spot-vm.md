---
status: "Proposed"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0018 - Bastion = RHEL 9.6 Spot VM (planned, blocked by quota)

## Context and problem statement

The lab needs a stable jump host that holds the operator tools
(`oc`, `kubectl`, `helm`, `kustomize`, `ansible`, `az`, the pull
secret). Running these from the workstation directly works but
mixes personal-tool state with lab state. A bastion in `uksouth`
also reduces RTT to the ARO clusters.

The bastion does not need to survive eviction — its configuration
lives in `infra/ansible/` (to be authored). So it can run as a
**Spot VM**, which discounts list price by ~80–90%.

## Decision drivers

- Cost: list-priced bastion would dominate the non-ARO line of the
  budget; Spot reduces it to ≈£5/month per the runbook §6.6.
- Reproducibility: nightly destruction + Ansible-driven rebuild is
  the structural defence; a Spot eviction is just an early rebuild.
- RHEL alignment: matches the OpenShift control plane node OS
  family, useful for the operator's familiarity.

## Status: PROPOSED — blocked

`standardBsv2Family` quota in `uksouth` is currently 0; the
`Standard_B4ms` instance we want to use is in this family. Until
the quota request (filed alongside the hub/virt requests, see
`scripts/setup/azure-bootstrap.md` §0) is approved, this ADR cannot
move to Accepted and the corresponding Terraform module cannot apply.

## Considered options

1. **`Standard_B4ms` Spot (B-series v2), accept eviction**, rebuild
   via `terraform apply` + Ansible.
2. **`Standard_D2s_v3` Spot**, slightly more capable.
3. **List-priced VM** (any size) — guaranteed availability, ~5–10×
   the cost.
4. **No bastion** — run everything from the workstation. Saves £5/month
   at the cost of workstation/lab state co-mingling.

## Decision outcome

Chosen option: **Option 1** when quota lands. 4 vCPU / 16 GiB is
ample for the operator toolchain; Spot pricing brings the bastion
into rounding-error territory.

Implementation will land as `infra/terraform/modules/bastion/` plus
`infra/ansible/bastion.yml` in a follow-up PR after the quota lands.

### Consequences

- Good: ≈£5/month worst case — fits inside the £190/month headroom
  on the £500 budget after ARO spend.
- Good: eviction is acceptable; rebuild is automated.
- Good: separates lab credentials (pull secret, kubeconfigs) from
  the personal workstation.
- Bad: Spot eviction during a long-running task interrupts work.
  Mitigation: keep tasks idempotent (`task` runner default).
- Bad: requires the `standardBsv2Family` quota increase, which
  blocks Phase 1 acceptance of this ADR.

## Validation

Once quota lands:

- [ ] Bastion provisions successfully via `task bastion:up`.
- [ ] Ansible playbook bootstraps the toolchain.
- [ ] `task bastion:down` cleanly destroys.
- [ ] First eviction (Azure-initiated): rebuild succeeds without
      manual intervention beyond rerunning `terraform apply`.

## Links

- Runbook §6.6
- ADR 0006 (cost ceiling)
- `scripts/setup/azure-bootstrap.md` (quota request list)
