# Learning roadmap

The sigma-platform work is broken into eight phases, each with its
own goal, deliverables, and acceptance criteria. The phases run
roughly in order, but parallelisable tracks are called out where
they exist.

## Status legend

- **DONE** — landed, acceptance criteria met.
- **PARTIAL** — some deliverables landed, others outstanding.
- **TODO** — designed but not yet started.
- **BLOCKED** — designed and ready to start, waiting on an external
  dependency (quota, vendor approval, …).

## Phase 0 — Foundations

**Status: DONE.**

Goal: a workstation and repo where it is physically difficult to
commit something that breaks anonymisation, schema validity, or the
cost discipline.

Deliverables:

- Pre-commit hooks: `yamllint`, `gitleaks`, `shellcheck`,
  `markdownlint`, conventional-commit linter, anonymisation
  back-stop.
- CI workflows: `lint`, `secret-scan`, `schema-validate` run on every
  PR and push to `main`.
- Anonymisation discipline captured in
  [ADR 0001](adr/0001-project-name-and-anonymisation.md) and the
  [`anonymisation` skill](../.claude/skills/anonymisation/SKILL.md).
- MADR-style [ADR template](adr/0000-template.md) and the first
  wave of ADRs (0001–0007).
- `Taskfile.yml` as the single entry point for every workflow.

Acceptance:

- [x] `task bootstrap` succeeds on a fresh checkout.
- [x] `pre-commit run --all-files` clean on `main`.
- [x] CI workflows green on `main`.

## Phase 1 — Azure bootstrap

**Status: PARTIAL** (shared env applied; hub/virt/bastion blocked on
quota; OIDC setup outstanding).

Goal: durable, audited Azure plane that the ephemeral env work can
build on.

Deliverables:

- `infra/terraform/envs/shared/` — resource group, AAD-authenticated
  state storage account with versioning and 30-day soft delete,
  subscription-scope £500 monthly budget with 50/80/100% alerts.
  See [ADR 0017](adr/0017-terraform-azurerm-backend.md) and
  [ADR 0019](adr/0019-monthly-budget-with-alerts.md).
- AAD application + federated credential for GitHub Actions
  (`scripts/setup/aad-oidc.sh`).
- `gh secret set` of `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
  `AZURE_SUBSCRIPTION_ID` on the repo.
- `.github/workflows/nightly-teardown.yml` — landed, gated on the
  OIDC creds above.
- `infra/terraform/envs/hub/` and `…/virt/` — Terraform modules for
  the ephemeral ARO clusters.
- `infra/terraform/envs/bastion/` — Spot VM bastion per
  [ADR 0018](adr/0018-bastion-rhel-spot-vm.md).

Acceptance:

- [x] Shared env state migrated to Azure SA; `terraform plan` clean
      on re-run.
- [x] Budget visible via `az consumption budget list`.
- [x] Nightly teardown workflow file merged.
- [ ] OIDC federated credential created and the three repo secrets
      populated.
- [ ] Nightly teardown workflow runs green on a manual dispatch
      (dry-run = true).
- [ ] `standardDSv3Family`, `standardDSv5Family`, `standardBsv2Family`
      quotas in `uksouth` approved.
- [ ] `task aro:up:hub` and `task aro:up:virt` apply cleanly under the
      `assert-none-running` invariant.
- [ ] Bastion provisions via `terraform apply` + Ansible.

Cost impact: shared env is ~£0. ARO envs each cost ≈£2.40/hr while
running.

## Phase 2 — GitOps bootstrap

**Status: TODO.**

Goal: ArgoCD on the ARO hub plus a working local kind cluster so
that every manifest from Phase 3 onwards lands via GitOps, not
imperatively.

Deliverables:

- `gitops/bootstrap/openshift-gitops-subscription.yaml` — installs
  the OpenShift GitOps operator on the hub.
- `gitops/bootstrap/root-application.yaml` — the root ArgoCD
  Application that sources every other Application from
  `gitops/apps/`.
- `gitops/apps/` and `gitops/overlays/` directory skeleton with at
  least one demonstrator app (e.g. `httpbin` or `podinfo`) deployed
  via an overlay.
- `task kind:up` produces a Cilium 1.19 (Helm) + KubeVirt + Forklift
  install on a fresh kind cluster. See
  [ADR 0008](adr/0008-cilium-scope-split.md).
- CRD schemas for `CiliumConfig`, `HyperConverged`, MTV `Provider`,
  MTV `Plan` fetched into `schemas/` so kubeconform validates them
  strict.

Acceptance:

- [ ] `task spin:up:hub` followed by `task gitops:bootstrap:hub`
      produces a synced root Application within 10 minutes.
- [ ] At least one demonstrator app reaches `Healthy` and `Synced`.
- [ ] `task kind:up` produces a working Cilium install verified by
      `cilium status`.
- [ ] `kustomize build gitops/overlays/<demo>/ | kubeconform -strict`
      green.

## Phase 3 — ACM multi-cluster

**Status: TODO.**

Goal: exercise multi-cluster ACM patterns with the ARO hub as the
hub and the local kind cluster imported as the spoke. See
[ADR 0005](adr/0005-one-aro-cluster-at-a-time.md).

Deliverables:

- ACM operator installation on the hub via GitOps (Phase 2 root app
  sources it).
- `task gitops:register-spoke` — `clusteradm join` against the hub,
  followed by `ManagedCluster` + `KlusterletAddonConfig` apply on
  the hub side.
- An ApplicationSet with a `Cluster` generator that deploys the
  Phase 2 demonstrator app to both `local-cluster` (the hub) and
  the kind spoke.

Acceptance:

- [ ] `oc get managedclusters` on the hub shows both
      `local-cluster` and `kind-sigma-kv` as `JOINED`.
- [ ] ApplicationSet produces two child Applications, both
      `Healthy`/`Synced`.
- [ ] Tearing down the kind cluster reflects as `OFFLINE` in ACM
      within 5 minutes; bringing it back up restores `JOINED`.

## Phase 4 — OpenShift Virtualization + MTV

**Status: TODO.**

Goal: KubeVirt + Forklift exercised live on the kind cluster as a
proxy for OpenShift Virtualization + MTV on bare metal; bare-metal
manifests written but not applied.

Deliverables:

- `task kind:install-kubevirt` + `task kind:install-forklift` —
  reproducible installs with software emulation enabled (no nested
  virt required on the laptop).
- `gitops/apps/mtv/` — anonymised MTV `Provider`, `NetworkMap`,
  `StorageMap`, `Plan` CR templates.
- `clusters/baremetal-reference/manifests/openshift-virtualization/`
  — the equivalent CRs for bare-metal OpenShift Virtualization, with
  `HyperConverged` config.
- A worked-example migration: import a tiny disk image via CDI,
  create a `VirtualMachine` CR on kind, demonstrate
  start/stop/console access.

Acceptance:

- [ ] KubeVirt `kubevirt-system` namespace reports `Deployed` in CR
      status.
- [ ] One `VirtualMachine` reaches `Running` on kind under emulation.
- [ ] All `clusters/baremetal-reference/manifests/` pass kubeconform
      strict against the schema set fetched in Phase 2.

## Phase 5 — Tests

**Status: TODO.**

Goal: every claim the repo makes is backed by an executable test.

Deliverables:

- `tests/e2e/go.mod` — Ginkgo v2 + Gomega e2e suite that targets a
  live ARO cluster (the hub during hub-day, the virt cluster during
  virt-day).
- `tests/terratest/go.mod` — Terratest suite that exercises each
  Terraform module in isolation, including teardown.
- Initial e2e coverage:
  - GitOps root Application reaches `Synced`/`Healthy` from a fresh
    cluster within a deadline.
  - ACM `ManagedCluster` registration round-trip.
  - At least one MTV smoke test against a stub provider.
- Initial Terratest coverage:
  - `envs/shared` apply + state migration + destroy.
  - `envs/hub` apply + destroy under the one-cluster invariant.

Acceptance:

- [ ] `task test:unit` green against both modules.
- [ ] `task test:e2e` green against a live hub after `task spin:up:hub`.
- [ ] CI gates the `lint` / `secret-scan` / `schema-validate` workflows
      on `tests/**` as well as the existing scopes.

## Phase 6 — Policies, ADR backfill, anonymisation audit

**Status: TODO** — gating the original "public flip" per
[ADR 0003](adr/0003-private-github-repo-personal-namespace.md);
since the repo is now public, the audit becomes a retrospective
deliverable, not a gate.

Goal: policy-as-code on both clusters; ADR set complete enough that
a reader can reconstruct every design choice; anonymisation
verified end-to-end.

Deliverables:

- ACM `Policy` patterns under `policies/acm/` (compliance, config
  drift, version pinning).
- Kyverno baseline policies under `policies/kyverno/` for the kind
  cluster.
- Backfill of any ADRs missing in the 0008–0016 range.
- Retrospective anonymisation audit: `git log -S` for every term in
  the populated forbidden-terms list across full history; new ADR
  capturing the result (zero hits required to close).

Acceptance:

- [ ] Each policy has a passing and a failing fixture, both covered
      by the Phase 5 e2e suite.
- [ ] `git log -S <token>` returns zero hits for every forbidden
      token, across `main` and every active branch.
- [ ] Audit ADR landed and linked from ADR 0003 as the
      supersession trigger.

## Phase 7 — Polyrepo split rehearsal

**Status: TODO** — validates the monorepo seam choice in
[ADR 0002](adr/0002-monorepo-layout.md).

Goal: prove the top-level directories are real boundaries by
lifting one out into its own repo and verifying nothing breaks.

Deliverables:

- `git filter-repo --subdirectory-filter gitops/` against a clone,
  producing a standalone `sigma-gitops` repo.
- CI workflows for the lifted repo: a stripped-down `lint` +
  `schema-validate` workflow that reuses the public action versions
  from this repo.
- Documentation of the lift procedure as `docs/polyrepo-split.md`,
  including the seam audit checklist.

Acceptance:

- [ ] Lifted repo builds and validates with zero edits to imports
      or paths.
- [ ] `task validate` in the lifted repo green.
- [ ] If the lift required edits, those become a new ADR closing
      the monorepo-seams-held question.

## Parallelisation notes

- Phase 1 and Phase 2's `task kind:up` workstream can proceed in
  parallel — kind doesn't need Azure.
- Phase 4's bare-metal manifest authoring can start any time after
  Phase 0; the live KubeVirt-on-kind exercise depends on Phase 2.
- Phase 6's anonymisation audit can be run any time the
  forbidden-terms list is populated; doing it now (rather than
  waiting until Phase 6) closes the ADR 0003 gate retroactively.

## Out of scope

Items that have come up in discussion but are explicitly **not** on
this roadmap:

- Production bare-metal Cilium with ACI underlay — captured only as
  reference manifests; no live exercise in this lab.
- BGP peering with a real fabric (Cilium BGP control plane).
- PTP / SR-IOV / DPDK — bare-metal-only, no Azure analogue.
- Production MTV warm migration with CBT-enabled vSphere sources —
  the Forklift-on-kind exercise covers the API surface only.
- A second contributor; this is a solo project by design.
