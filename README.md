# sigma-platform

[![lint](https://github.com/sholaj/sigma-platform/actions/workflows/lint.yml/badge.svg)](https://github.com/sholaj/sigma-platform/actions/workflows/lint.yml)
[![secret-scan](https://github.com/sholaj/sigma-platform/actions/workflows/secret-scan.yml/badge.svg)](https://github.com/sholaj/sigma-platform/actions/workflows/secret-scan.yml)
[![schema-validate](https://github.com/sholaj/sigma-platform/actions/workflows/schema-validate.yml/badge.svg)](https://github.com/sholaj/sigma-platform/actions/workflows/schema-validate.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

A reference monorepo documenting the operational patterns behind an
OpenShift Virtualization migration: Agent-Based Installer clusters,
Isovalent Cilium 1.19, Red Hat ACM, ArgoCD, and the Migration Toolkit
for Virtualization, with the GitOps discipline that ties them
together. Patterns are exercised on Azure Red Hat OpenShift and local
kind clusters under a tight cost ceiling; bare-metal target manifests
live alongside as reference artifacts.

This repository is anonymised by design. Every artifact is treated as
world-readable forever. See [ADR 0001](docs/adr/0001-project-name-and-anonymisation.md)
for the posture and [docs/glossary.md](docs/glossary.md) for the
placeholder substitutions.

## What you'll find here

- **Phased roadmap** ([docs/learning-roadmap.md](docs/learning-roadmap.md)) —
  the path from a local kind cluster to bare-metal-ready manifests,
  broken into deliverable phases with explicit acceptance criteria.
- **Architecture Decision Records** ([docs/adr/](docs/adr/)) — every
  significant choice captured against the
  [MADR template](docs/adr/0000-template.md), including the
  alternatives that didn't win.
- **Ephemeral ARO operating pattern** — one cluster at a time, daily
  teardown, sub-£500/month operating envelope, structural guardrails
  rather than willpower. See ADRs
  [0005](docs/adr/0005-one-aro-cluster-at-a-time.md),
  [0006](docs/adr/0006-cost-ceiling-ephemeral-clusters.md),
  [0019](docs/adr/0019-monthly-budget-with-alerts.md).
- **Cilium 1.19 reference manifests** for bare-metal OpenShift, with
  live Cilium exercised on kind via Helm. The scope split (kind vs
  reference vs ARO) is enforced in the
  [`cilium-openshift` skill](.claude/skills/cilium-openshift/SKILL.md).
- **MTV migration scaffolding** — Provider, NetworkMap, StorageMap,
  Plan CRs as anonymised templates aligned to the current MTV API.
- **CI back-stops** — pre-commit hooks plus three workflows
  ([`lint`](.github/workflows/lint.yml),
  [`secret-scan`](.github/workflows/secret-scan.yml),
  [`schema-validate`](.github/workflows/schema-validate.yml))
  that enforce schema validity, anonymisation, and lint health on
  every change.
- **Agent skill files** ([`.claude/skills/`](.claude/skills/)) —
  read by Claude Code and surfaced as repository context for other
  AI coding agents. The patterns work without them; they're an
  accelerant, not a dependency.

## What this isn't

- **Not production-ready.** It's a learning artifact. Don't deploy
  any of this to anything that matters without an ADR of your own.
- **Not a tutorial.** The ADRs and roadmap document the reasoning;
  the code is reference, not step-by-step.
- **Not customer-specific.** All identifiers are placeholders. If
  you spot a real-looking token in this repo's history, please open
  a private security advisory — see [SECURITY.md](SECURITY.md).
- **Not accepting external PRs.** Solo project by design. See
  [CONTRIBUTING.md](CONTRIBUTING.md).

## Repo layout

```text
clusters/           OpenShift install configs (hub, virt, kind, baremetal-reference)
gitops/             ArgoCD Applications, ApplicationSets, root bootstrap
policies/           ACM and Kyverno policy patterns
infra/              Azure Terraform modules and Ansible playbooks
tests/              Go e2e (Ginkgo + Gomega) and IaC (Terratest)
docs/adr/           Architecture Decision Records
docs/glossary.md    Anonymisation placeholder reference
.claude/skills/     Agent-readable skill files
Taskfile.yml        Entry point for every workflow (try `task --list-all`)
```

Each top-level seam directory is intentionally a future-repo
boundary; see [ADR 0002](docs/adr/0002-monorepo-layout.md) for the
monorepo-with-polyrepo-seams reasoning.

## Topology constraint

One ARO cluster runs at any time — hub or virt, never both.
Multi-cluster ACM patterns use the ARO hub plus a local kind cluster
as the spoke. ARO retains its managed OVN-Kubernetes CNI; Cilium 1.19
is exercised live on kind via Helm and captured as bare-metal install
manifests under `clusters/baremetal-reference/`, never applied to
ARO. The reasoning is in
[ADR 0004](docs/adr/0004-tech-stack.md) and
[ADR 0005](docs/adr/0005-one-aro-cluster-at-a-time.md).

## Getting started

```bash
# 1. Install the toolchain (macOS via Homebrew)
brew install pre-commit go-task yamllint gitleaks kubeconform kube-linter \
             gh terraform azure-cli jq gnupg kubectl helm kustomize

# 2. Clone and bootstrap
git clone https://github.com/sholaj/sigma-platform.git
cd sigma-platform
task bootstrap        # verifies tools, installs pre-commit + commit-msg hooks

# 3. Populate the private forbidden-terms file (see ADR 0001)
mkdir -p ~/.config/sigma-platform
$EDITOR ~/.config/sigma-platform/gitleaks-forbidden.toml

# 4. Read the roadmap
$EDITOR docs/learning-roadmap.md
```

If you skip step 3, the anonymisation pre-commit hook runs the
structural rules only and prints a warning. Don't rely on that.

## Reading order

1. [ADR 0001 — Project name and anonymisation posture](docs/adr/0001-project-name-and-anonymisation.md)
   — the foundation everything else assumes.
2. [ADR 0004 — Tech stack](docs/adr/0004-tech-stack.md) and
   [ADR 0005 — One ARO cluster at a time](docs/adr/0005-one-aro-cluster-at-a-time.md)
   — what this lab does and why.
3. [docs/learning-roadmap.md](docs/learning-roadmap.md) — phased
   deliverables and current state.
4. The remaining ADRs in numeric order.

## Status

Work in progress. Phase 0 (tooling, hooks, CI back-stops,
anonymisation discipline) is complete. Phase 1 (Azure bootstrap,
Terraform state storage, monthly budget) is partially landed —
the `shared` Terraform env applies cleanly; the `hub`, `virt`, and
`bastion` envs are stubbed pending vCPU quota approval in `uksouth`
([details](scripts/setup/azure-bootstrap.md)). The Taskfile's
`spin:up:*` targets refuse to run until the corresponding env
directories carry a `main.tf`.

Track progress through the ADR set and the `docs/learning-roadmap.md`
phase headings.

## License

[Apache-2.0](LICENSE).
