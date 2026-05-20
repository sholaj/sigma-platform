---
status: "Accepted"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0004 - Tech stack

## Context and problem statement

The repo simulates patterns from a real OpenShift Virtualization
migration. The technology choices are partly inherited from the
production target and partly driven by what is exercisable on a
£500/month Azure budget.

## Decision drivers

- Production target uses OpenShift Virtualization on bare metal with
  Isovalent Cilium 1.19 and Cisco ACI underlay. The lab must
  approximate the patterns even where it cannot reproduce the
  substrate.
- Solo learning cadence: prefer tools whose docs and ecosystems are
  mature and stable.
- Cost discipline: managed services (ARO) keep the operator close
  to the production support contract.

## Decision outcome

Chosen stack (locked):

- **Container platform**: OpenShift 4.20 (ARO for the live lab
  cluster; bare-metal patterns codified as reference manifests).
- **CNI**: Cilium 1.19 on local kind (Helm); ARO clusters retain
  their managed OVN-Kubernetes. See ADR 0008.
- **GitOps**: ArgoCD via the OpenShift GitOps Operator.
- **Multi-cluster**: Red Hat ACM on the ARO hub, with a local kind
  cluster imported as the spoke.
- **Migration tooling**: Migration Toolkit for Virtualization (MTV),
  with Forklift as the upstream equivalent used on kind.
- **Provisioning**: Ansible 9+ for RHEL 9.6 bastion config; Terraform
  (`azurerm` >= 4.0) for Azure.
- **Tests**: Go 1.22+ with Ginkgo v2 + Gomega for e2e; Terratest for IaC.
- **Bastion OS**: RHEL 9.6 (Spot VM).

### Consequences

- Good: every choice has a direct analogue in the production target.
- Good: Go-based test stack reuses the operator's existing skill set.
- Bad: Cilium is exercised on kind only — the OLM-on-OpenShift install
  surface is left as reference. See ADR 0008.
- Bad: Bare-metal-only features (PTP, SR-IOV, ACI integration) are
  documentation, not exercise.

## Validation

Each phase produces durable artifacts. If a phase's deliverables
require a tool outside this list, that's a re-open of this ADR.

## Links

- ADR 0005 (one-cluster-at-a-time topology)
- ADR 0008 (Cilium scope split)
