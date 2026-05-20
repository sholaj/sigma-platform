---
name: cilium-openshift
description: |
  Use this skill for any work involving Cilium on OpenShift — Cilium
  1.19 via the Isovalent OLM operator, CiliumConfig CRs,
  CiliumNetworkPolicy, CiliumClusterwideNetworkPolicy, Hubble, eBPF
  datapath choices, native routing CIDRs, or the cluster bootstrap
  flow. Also use when the user mentions Cisco ACI underlay
  considerations or BGP peering with the fabric.
---

# Cilium 1.19 on OpenShift 4.20

## CRITICAL CAVEAT — read first

This project's ARO clusters DO NOT and CANNOT run Cilium. Azure Red
Hat OpenShift is a managed service; the CNI is selected and operated
by Microsoft+Red Hat (OVN-Kubernetes). There is no `install-config.yaml`
the operator can edit and no `openshift-install create cluster` step
on ARO — those exist only for self-managed OpenShift (IPI/UPI/Assisted).

Therefore, in this repository:

1. **Live Cilium experimentation runs on the local kind cluster only.**
   See `scripts/kind/up.sh` and ADR 0008. The kind cluster installs
   Cilium via the standard Helm chart (NOT the OLM operator — OLM is
   OpenShift-only).
2. **Cilium-on-OpenShift manifests for the bare-metal target live in
   `clusters/baremetal-reference/manifests/`** as ADR-backed reference
   artifacts. They are validated by kubeconform and reviewed in PRs,
   but they are NEVER applied to any cluster in this lab.
3. **ARO clusters keep their default OVN-Kubernetes CNI.** All
   NetworkPolicy work targeted at ARO uses standard
   `networking.k8s.io/v1 NetworkPolicy`, not `CiliumNetworkPolicy`.

If the user asks for Cilium manifests destined for ARO, STOP and
clarify — they almost certainly want either (a) bare-metal reference
artifacts, or (b) work redirected to the kind cluster.

## Before generating manifests

Invoke fetch-live-docs. Fetch:

- https://github.com/isovalent/olm-for-cilium  (README + manifests/cilium.v1.19.x/)
- https://docs.cilium.io/en/v1.19/installation/k8s-install-openshift-okd/

## Bare-metal install order (REFERENCE — not executed on ARO)

For the real bare-metal target the operator will follow this flow.
This sequence is captured here so the manifests in
`clusters/baremetal-reference/` make sense to a future reader. None
of these commands run against ARO.

1. `openshift-install create manifests --dir <cluster-name>`
2. Set `networkType: Cilium` in `install-config.yaml`'s networking block.
3. Clone isovalent/olm-for-cilium, copy
   `manifests/cilium.v1.19.x/*` into `<cluster-name>/manifests/`.
4. Tune `cluster-network-07-cilium-ciliumconfig.yaml`:
   - clusterNetwork CIDR must match Cilium's clusterPoolIPv4PodCIDRList
   - clusterNetwork must NOT collide with the underlay CIDR
   - On OpenShift the VXLAN port defaults to UDP 4789 (IANA), not 8472.
   - clusterHealthPort 9940 (not the Cilium default; OpenShift blocks
     low-range ports on many providers)
5. `openshift-install create cluster --dir <cluster-name>`

## Cilium on kind (ACTUALLY executed)

Use the upstream Helm chart, not the OLM operator. OLM is an OpenShift
construct; on kind it does not apply.

```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium \
  --version 1.19.x \
  --namespace kube-system \
  --set image.pullPolicy=IfNotPresent \
  --set ipam.mode=kubernetes
```

## ACI underlay considerations (theory — ADR TBD)

ACI is not present in any lab cluster. The production design has not
yet been formally captured as an ADR (the original placeholder
"ADR 0007" was claimed by the branch-protection decision; a dedicated
ACI underlay ADR is on the backlog for Phase 6).

When that ADR is written, it should capture policy patterns that
translate cleanly to bare-metal:

- BGP advertisement of pod CIDRs (Cilium BGP control plane)
- Per-namespace egress IP pools
- DSR for north-south traffic

Until then, treat any ACI integration discussion in PRs as
design-intent material requiring its own ADR before manifests land.

## Day-2 (bare-metal reference)

Update CiliumConfig with `kubectl edit ciliumconfig -n cilium cilium`.
Some changes need a Cilium agent rolling restart — call this out in PRs.
