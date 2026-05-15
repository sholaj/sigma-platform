# sigma-platform — Copilot repository instructions

## Project type

Private reference monorepo (for now) for OpenShift Virtualization
migration patterns. Solo contributor. Tech stack: OpenShift 4.20,
Cilium 1.19 (on kind / bare-metal-reference only), ArgoCD,
Red Hat ACM, Migration Toolkit for Virtualization (MTV), Ansible,
Terraform, Go (Ginkgo v2 + Gomega), RHEL 9.6.

## Cluster topology constraint

Only ONE ARO cluster runs at any time (hub OR virt, never both).
Multi-cluster ACM patterns are simulated using the ARO hub plus a
local kind cluster as the spoke. ARO clusters run their managed
OVN-Kubernetes CNI; Cilium 1.19 is exercised live on kind and
captured as bare-metal reference manifests under
`clusters/baremetal-reference/`.

## Critical anonymisation rules (override everything)

Never generate code, comments, commit messages, or prose containing:

- Specific client / customer names
- Specific vendor partner / consulting firm names
- The words "bank", "banking", "insurance", "trading", "wealth",
  "private banking", any regulator acronym
- Real public IPs, real ASNs, real internal hostnames
- City / country / building / datacentre names linked to the engagement
- Any project codename other than `sigma-platform`

Use the placeholders in `docs/glossary.md` (`Example Org`, `Example
Partner`, `192.0.2.0/24`, `example.com`, `bastion-01`, `aro-hub-01`,
etc.). If a real-looking identifier is needed, ASK before generating.

## Documentation-first

For OpenShift, MTV, Cilium, ACM, ArgoCD, KubeVirt, or any `az aro`
command, fetch the current upstream docs before producing config.
Do not generate manifests from memory.

Canonical sources:

- OpenShift 4.20: docs.redhat.com/en/documentation/openshift_container_platform/4.20/
- OpenShift Virtualization on ARO: learn.microsoft.com/en-us/azure/openshift/howto-create-openshift-virtualization
- MTV: docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/
- Cilium 1.19: docs.cilium.io/en/v1.19/
- Isovalent OLM for Cilium: github.com/isovalent/olm-for-cilium
- ACM: docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/
- ArgoCD: argo-cd.readthedocs.io/en/stable/
- `az aro` CLI: learn.microsoft.com/en-us/cli/azure/aro

## Conventions

- Conventional Commits, enforced by commitlint.
- Every "architecturally significant" choice gets an ADR in
  `docs/adr/NNNN-<slug>.md` using the MADR template.
- All YAML must pass `yamllint`, `kubeconform -strict`, and
  `kube-linter`. ArgoCD Application manifests must also pass
  `kustomize build | kubeconform -`.
- Terraform: `azurerm` provider, state in remote Azure Storage with
  `azurerm` backend and state locking.
- Go: 1.22+, tests with Ginkgo v2 + Gomega, IaC tests with Terratest.
- Task runner: `Taskfile.yml`. Prefer `task <name>` over ad-hoc shell.
- Pre-commit hooks must pass before any commit.

## Commit attribution

Do NOT append `Co-Authored-By:` trailers.

## Build / run / verify

- `task lint` — full lint suite
- `task validate` — schema validation across all manifests
- `task test:unit` — Go unit tests
- `task test:e2e` — Ginkgo e2e against a live cluster
- `task spin:up:hub` — provision hub cluster
- `task spin:down:all` — destroy everything (DEFAULT END-OF-DAY)

## When unsure

Open an ADR rather than make a silent design choice. When ambiguity
is operational rather than architectural, leave a `// TODO(sigma):`
comment.
