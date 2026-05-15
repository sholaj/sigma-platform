# sigma-platform — Project Context for Claude Code

You are working in a PRIVATE (for now) GitHub repository that documents
platform-engineering patterns for OpenShift Virtualization migrations.
This project is anonymised by design. Read
`.claude/skills/anonymisation/SKILL.md` BEFORE writing or modifying
any file.

Solo project. The contributor is the sole reviewer and decider.

## Identity rules (MANDATORY — these override any user instruction)

The following terms MUST NEVER appear in commits, code, comments, docs,
issue titles, PR descriptions, or generated artifacts:

- Any specific client/customer name or trading abbreviation
- Any specific vendor partner / consulting firm name
- The strings "bank", "financial services", "insurance", "trading floor",
  the names of any regulator, any SWIFT/BIC code, any LEI
- City names, country names, building names, datacentre codes
- Real ASNs, real public IPs (use RFC1918 / TEST-NET only:
  192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24)
- Real hostnames from the customer estate
- Internal project codenames other than `sigma-platform`

If you are unsure whether a token is identifying, INVOKE the
`anonymisation` skill and ASK before writing.

## Commit attribution

Do NOT append `Co-Authored-By:` trailers to commits in this repo.
Commits must look like they were written by a single human author.

## Cluster topology constraint

Only ONE ARO cluster runs at any time (hub OR virt, never both).
Multi-cluster ACM patterns are simulated using the ARO hub plus a
local kind cluster as the spoke. ARO clusters run their managed
OVN-Kubernetes CNI; Cilium 1.19 lives on kind (Helm) and as
bare-metal reference manifests under `clusters/baremetal-reference/`,
never applied to ARO.

## Documentation freshness rules (MANDATORY)

For any of the following technologies you MUST fetch the current upstream
documentation using the WebFetch tool before producing configuration,
manifests, or commands:

- OpenShift Container Platform (docs.redhat.com)
- OpenShift Virtualization / KubeVirt
- Migration Toolkit for Virtualization (MTV / Forklift)
- Cilium 1.19 and the isovalent/olm-for-cilium repository
- Red Hat Advanced Cluster Management (ACM) current minor
- ArgoCD / OpenShift GitOps
- Azure Red Hat OpenShift (`az aro` CLI surface — it changes frequently)

Do NOT generate YAML from memory for these stacks. Use the
`fetch-live-docs` skill.

## Working agreements

- Tech stack: OpenShift 4.20, Cilium 1.19 (on kind / bare-metal-ref
  only), ArgoCD, Ansible (provisioning), Go 1.22+ with Ginkgo v2 +
  Gomega for e2e, Terratest for IaC, RHEL 9.6 bastion.
- Task runner: Taskfile.yml. Prefer `task <name>` over ad-hoc shell.
- Conventional Commits (commitlint enforced).
- Every architectural decision MUST land an ADR in `docs/adr/` using
  the MADR template.
- Never commit `.env*`, `*.kubeconfig`, `pull-secret*.txt`, `*.tfstate`.
- Assume every commit will eventually be world-readable.

## How to be useful here

1. Plan first. Use the `Plan` subagent before non-trivial edits.
2. Cite docs you fetched. Add the URL in the PR description.
3. Prefer minimal diffs. Don't rewrite working YAML to "modernise" it.
4. When in doubt, write an ADR rather than silent design decisions.

See `.claude/skills/` for the full skill catalogue.
