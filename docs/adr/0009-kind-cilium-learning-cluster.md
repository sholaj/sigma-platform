---
status: "Accepted"
date: 2026-05-24
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0009 - Kind cluster shape for the Cilium learning loop

## Context and problem statement

ADR 0008 made the scope split explicit: live Cilium experimentation
happens on a local kind cluster, and the Isovalent OLM operator path
stays in `clusters/baremetal-reference/` as a read-only artifact.
That ADR did not pin the *shape* of the kind cluster, and the kind
config that landed alongside `task kind:up` referenced a future ADR
that did not exist yet.

This ADR fixes that gap: it records the topology, datapath, and
Helm values that the Phase-2 learning loop is built on, and the
features that are intentionally *not* enabled in the default install
so the learning ladder has somewhere to climb.

## Decision drivers

- The cluster has to come up fast enough that re-creating it on every
  experiment is comfortable, otherwise the learning loop dies.
- The same cluster has to be usable for the Phase-4 KubeVirt +
  Forklift exercises without a re-pave.
- Features that are themselves learning topics (kube-proxy
  replacement, WireGuard transparent encryption, BGP control plane)
  must be reachable but not switched on by default — otherwise the
  default install hides the very thing it is meant to teach.
- The reference manifests in `clusters/baremetal-reference/` are the
  contract for production. Where the kind defaults can match the
  bare-metal posture cheaply, they should; where they cannot (no
  underlay, no nested virt), the gap is documented rather than
  faked.

## Considered options

1. Single-node kind, Cilium default Helm install, kube-proxy left
   in place.
2. Three-node kind (1 control-plane + 2 workers), Cilium default
   Helm install with Hubble, kube-proxy left in place.
3. Three-node kind, Cilium with kube-proxy replacement + WireGuard
   on from day one (closest to a production posture).
4. Two clusters: a tiny single-node "Cilium-only" learner and a
   separate three-node cluster for KubeVirt.

## Decision outcome

Chosen option: **Option 2** — three nodes, Cilium 1.19 via the
upstream Helm chart with Hubble (relay + UI), kube-proxy retained,
no encryption, no BGP.

Concretely (see `clusters/kind-local/kind-config.yaml` and
`scripts/tasks/kind.yml`):

- `kind.x-k8s.io/v1alpha4` config with `disableDefaultCNI: true`.
  kindnet would otherwise claim the CNI seat before Cilium can
  install its dataplane.
- Three nodes: one control-plane, two workers. Two workers is the
  minimum that lets pod-to-pod traffic actually cross a node
  boundary in Hubble, which is the whole point of the learning
  loop.
- kube-proxy is **left in place**. Cilium's kube-proxy replacement
  is a Phase-2 learning topic in its own right; the default install
  must demonstrate the "with kube-proxy" baseline so the switch-off
  has something to contrast against.
- Helm values: `ipam.mode=kubernetes` (kind allocates pod CIDRs per
  node, so the Kubernetes IPAM mode is the right fit, not
  cluster-pool), `hubble.{enabled,relay.enabled,ui.enabled}=true`,
  `image.pullPolicy=IfNotPresent` so re-runs do not re-pull on
  every cluster re-create.
- Datapath: VXLAN (the upstream default). Native routing requires
  an underlay the lab does not have.
- Task split: `task kind:up:cilium` is the fast learning entrypoint;
  `task kind:up:full` layers KubeVirt + CDI + Forklift on top for
  the Phase-4 exercises.

Option 1 (single node) was rejected because Hubble has nothing
interesting to show without inter-node traffic. Option 3 (KPR +
WireGuard from day one) was rejected because both are themselves
learning topics; enabling them by default would hide the toggle the
exercises are meant to flip. Option 4 (two clusters) was rejected
because the laptop budget does not justify two clusters where one
with two entrypoints does the job.

### Consequences

- Good: `task kind:up:cilium` is the smallest install path that
  still demonstrates pod-to-pod across a node boundary in Hubble.
- Good: every feature deferred to a later phase (KPR, WireGuard,
  BGP, native routing) is reachable by editing the same Helm
  install task; no cluster re-pave required for most of them.
- Good: the Helm value set tracks the `cilium-openshift` skill's
  recommended baseline for non-OpenShift clusters, so the learning
  here carries over to reading the bare-metal reference manifests.
- Bad: no underlay means BGP control plane and native routing
  cannot be exercised in any realistic sense on this cluster — the
  bare-metal manifests remain reference-only for those.
- Bad: software emulation for KubeVirt (Phase 4) is slow and
  occasionally flaky. That is a Phase-4 problem, not a Phase-2
  one, but it is the reason `up:cilium` and `up:full` are split.
- Bad: leaving kube-proxy in place means the default install is
  *not* the production posture. The roadmap has to call out the KPR
  flip explicitly or the reader will assume the kind cluster
  mirrors bare-metal.

## Validation

- [ ] `task kind:up:cilium` on a fresh checkout finishes in under
      five minutes on the workstation and `task kind:cilium-status`
      reports `OK`.
- [ ] `task kind:hubble-ui` exposes the Hubble UI at
      `http://localhost:12000` with at least one pod-to-pod flow
      visible after the demonstrator app is deployed.
- [ ] `task kind:up:full` succeeds on the same cluster spec without
      modification to the kind config.
- [ ] Re-running `task kind:up:cilium` against an existing cluster
      is a no-op (Helm `upgrade --install` and the `|| true` on
      `kind create cluster` make it idempotent).

## Links

- ADR 0004 — tech stack baseline
- ADR 0008 — Cilium scope split (live on kind, reference on
  bare-metal, never on ARO)
- `.claude/skills/cilium-openshift/SKILL.md`
- Cilium 1.19 kind install guide —
  https://docs.cilium.io/en/v1.19/installation/kind/
- Cilium Helm reference (v1.19) —
  https://docs.cilium.io/en/v1.19/helm-reference/
