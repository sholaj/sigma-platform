---
status: "Accepted"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0017 - Terraform with azurerm backend, state in shared SA

## Context and problem statement

Phase 1 brings IaC online. State has to live somewhere durable and
auditable, and the choice colours every downstream env (hub, virt,
bastion). The shared env creates the storage account that will hold
its own state — a one-time bootstrap dance is required.

## Decision drivers

- One contributor, one workstation today, but plausibly a second
  workstation later. State must be reachable from anywhere with the
  right Entra identity.
- Anonymisation: the project is private but treated as world-readable.
  State files would contain real subscription IDs and resource IDs —
  must not land in the repo.
- Free of additional cost: an Azure Storage account holding ≤1 MB of
  state is rounding error against the £500 budget.

## Considered options

1. **`azurerm` backend in a shared SA**, AAD auth, blob versioning on.
2. **Terraform Cloud / HCP Terraform** — free tier exists but adds a
   second SaaS dependency for a learning lab.
3. **S3-style remote backend in another cloud** (e.g., a personal AWS
   bucket) — defeats the "all infra in one place" goal.
4. **Local state, never migrated** — fails when state outgrows one
   workstation; loses audit history; trivially lost.

## Decision outcome

Chosen option: **Option 1** — `azurerm` backend, single SA
`sigmatf<random6hex>` in `rg-sigma-shared-uksouth`, container
`tfstate`, one blob per env (key = `<env>.tfstate`),
`use_azuread_auth = true`. Versioning + 30-day soft delete enabled.

Bootstrap procedure: first apply uses local backend; the apply
creates the SA; `terraform init -migrate-state` then moves state
into the new SA. Documented in
`scripts/setup/azure-bootstrap.md`.

### Consequences

- Good: state is durable, versioned, locked-via-lease, and accessible
  only via AAD identities (no shared keys).
- Good: every env's state lives next to the others — `az storage
  blob list` is the audit surface.
- Good: blob versioning means an accidental `terraform destroy` can
  be recovered from a prior version.
- Bad: one-time bootstrap is a manual dance (local → remote
  migration). Documented and reproducible.
- Bad: a corrupted lease leaves the state unwritable — recovery is
  `az storage blob lease break`, also documented.
- Bad: SA name must be globally unique — the 6-char hex suffix is
  a defence; recreate with a fresh suffix if collision occurs.

## Validation

Phase 1 acceptance criteria:

- [ ] `terraform plan` in the shared env produces no diff after
      the first apply + migration.
- [ ] Restarting the workstation and running `terraform init`
      again in a fresh checkout pulls state from the SA.
- [ ] Versioning is enabled on the SA (`az storage account blob-service-properties show`).

## Links

- ADR 0001 (anonymisation posture — no state in repo)
- ADR 0006 (cost ceiling — state SA is rounding error)
- `infra/terraform/envs/shared/versions.tf` (backend block)
- `scripts/setup/azure-bootstrap.md` (bootstrap dance)
- HashiCorp docs: https://developer.hashicorp.com/terraform/language/settings/backends/azurerm
