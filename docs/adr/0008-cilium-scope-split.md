---
status: "Accepted"
date: 2026-05-20
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0008 - Cilium scope split: live on kind, reference for bare-metal, never on ARO

## Context and problem statement

The production target is OpenShift Virtualization on bare metal with
Isovalent Cilium 1.19 as the CNI. The lab budget supports Azure Red
Hat OpenShift, but ARO is a managed service: the CNI is selected and
operated by Microsoft and Red Hat (OVN-Kubernetes). There is no
`install-config.yaml` step on ARO and no operator-side toggle that
swaps the CNI to Cilium.

Cilium therefore cannot run on the live lab cluster. The decision is
how to keep Cilium in scope as a learning artifact without
misleading directory layouts that pretend it's installed on ARO, and
without losing the production install path captured during the
upstream PoC.

This ADR makes explicit a scope split that was previously implicit
in the codebase and forward-referenced from ADR 0004 and the
`cilium-openshift` skill — both originally pointing to a never-written
ADR 0007 (the 0007 slot was claimed by the branch-protection ADR).

## Decision drivers

- Bare-metal Cilium install via the Isovalent OLM operator is the
  production target; manifests must remain valid and reviewable.
- Cilium APIs (`CiliumNetworkPolicy`, `CiliumClusterwideNetworkPolicy`,
  `CiliumConfig`) need somewhere to be exercised live, not just
  schema-validated.
- Mixing ARO clusters and Cilium manifests in the same directory tree
  risks an "apply to wrong cluster" mistake under time pressure.
- OLM is an OpenShift construct; it does not translate to kind. A
  uniform install path across both substrates is not available.

## Considered options

1. Cilium on ARO — impossible; see Context.
2. Cilium live on a self-managed OpenShift cluster on Azure VMs
   (IPI on Azure).
3. Cilium live on local kind via Helm; bare-metal manifests as
   read-only reference artifacts; ARO untouched.
4. No live Cilium — manifests only, validated by kubeconform.

## Decision outcome

Chosen option: **Option 3** — a three-way scope split:

- **Live Cilium experimentation runs on the local kind cluster.**
  `task kind:up` installs Cilium 1.19 via the upstream Helm chart
  (not OLM — OLM is OpenShift-only). `CiliumNetworkPolicy` and
  `CiliumClusterwideNetworkPolicy` are exercised here.
- **Cilium-on-OpenShift manifests for the bare-metal target live in
  `clusters/baremetal-reference/manifests/`** as ADR-backed reference
  artifacts. They are schema-validated by kubeconform and reviewed in
  PRs, but they are never applied to any cluster in this lab.
- **ARO clusters keep their default OVN-Kubernetes CNI.** All
  NetworkPolicy work targeted at ARO uses standard
  `networking.k8s.io/v1 NetworkPolicy`, not `CiliumNetworkPolicy`.

Option 2 (self-managed OpenShift on Azure VMs) was rejected on cost
and operational burden: the bare-metal install path is the artifact
that matters, and exercising it on Azure VMs would consume the
budget headroom needed for ARO without producing a meaningfully
different artifact than the reference manifests already capture.

### Consequences

- Good: Cilium APIs exercised live (on kind), production install
  path captured (in `baremetal-reference/`), zero ambiguity about
  what runs where.
- Good: kind's Helm install matches the upstream-recommended path
  for non-OpenShift clusters, not the OLM operator (which would not
  apply there anyway).
- Good: kubeconform `schema-validate` keeps the bare-metal manifests
  honest on every PR.
- Bad: kind on a laptop is not a perfect substrate — no real ACI
  underlay, no fabric BGP, no nested-virt for KubeVirt without
  `useEmulation`. Bare-metal-only Cilium features (BGP control
  plane, DSR, native routing across an underlay) are not exercised
  live.
- Bad: two install paths (Helm on kind, OLM on bare-metal) means two
  sets of manifests with overlapping content. The `cilium-openshift`
  skill is the authoritative cross-reference.

## Validation

- [ ] `task kind:up` produces a working Cilium 1.19 install on a
      fresh kind cluster; `cilium status` reports `OK`.
- [ ] `clusters/baremetal-reference/manifests/` passes kubeconform
      strict validation in the `schema-validate` workflow.
- [ ] No file under `clusters/baremetal-reference/` is referenced by
      any `task spin:up:*` target — verifiable by grep in CI.
- [ ] `task kind:install-cilium` is idempotent across re-runs.

## Links

- ADR 0004 (tech stack — references this scope split)
- ADR 0005 (one-cluster-at-a-time topology)
- `.claude/skills/cilium-openshift/SKILL.md`
- Isovalent OLM for Cilium — https://github.com/isovalent/olm-for-cilium
- Cilium 1.19 OpenShift install — https://docs.cilium.io/en/v1.19/installation/k8s-install-openshift-okd/
