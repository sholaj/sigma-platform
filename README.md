# sigma-platform

A reference monorepo for platform engineers exploring the operational
patterns around OpenShift Virtualization migrations, Isovalent Cilium,
Red Hat Advanced Cluster Management, and GitOps with ArgoCD.

This repository is a sandbox. It does not contain production
configurations and is not affiliated with any specific customer
engagement. All examples use anonymised placeholders.

## What's here

- `clusters/` — OpenShift install configs (hub + virt + local kind + bare-metal reference)
- `gitops/` — ArgoCD Applications and ApplicationSets
- `policies/` — ACM and Kyverno policy patterns
- `infra/` — Azure Terraform modules and Ansible playbooks
- `tests/` — Go-based e2e (Ginkgo) and IaC (Terratest) tests
- `docs/adr/` — Architecture Decision Records
- `docs/learning-roadmap.md` — Phase-by-phase walkthrough

## Topology

Solo contributor. **One ARO cluster at a time** (hub OR virt, never
both). Multi-cluster ACM patterns use the ARO hub plus a local kind
cluster as the spoke. ARO clusters run their managed OVN-Kubernetes
CNI; Cilium 1.19 lives on kind only, with bare-metal install
manifests kept as reference artifacts.

## Getting started

1. Install the toolchain: `brew install pre-commit go-task yamllint gitleaks kubeconform kube-linter`
2. Clone the repo and `cd` into it.
3. `pre-commit install` to wire up the hooks.
4. Copy `~/.config/sigma-platform/gitleaks-forbidden.toml.template` to `gitleaks-forbidden.toml` and populate with the real forbidden tokens.
5. See `docs/learning-roadmap.md` for the phased walkthrough.

## License

Apache-2.0.
