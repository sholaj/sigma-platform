---
status: "Accepted"
date: 2026-05-15
deciders: ["@sholaj"]
consulted: []
informed: []
---

# 0002 - Monorepo layout with polyrepo-friendly seams

## Context and problem statement

Solo project covering IaC, GitOps manifests, policies, cluster
install configs, and Go tests. Single repo is simpler operationally
but risks coupling across boundaries that should later become
independent repos.

## Decision drivers

- Solo cadence makes one PR review easier than many.
- The artifacts have clean conceptual seams
  (IaC vs gitops vs tests vs policies).
- Future polyrepo split should not require import rewrites or shared
  module shims.

## Considered options

1. One repo per concern from day 0.
2. Single monolith with cross-cutting Go modules.
3. Monorepo with polyrepo-friendly seam directories
   (`clusters/`, `gitops/`, `policies/`, `infra/`, `tests/`), each
   carrying its own dependencies.

## Decision outcome

Chosen option: **Option 3**. Each top-level seam directory can be
lifted into its own repo via `git filter-repo --subdirectory-filter
<dir>` later without rewiring imports. `tests/e2e` and
`tests/terratest` each carry their own `go.mod`.

### Consequences

- Good: one place to read, one place to commit.
- Good: Phase 7 rehearses the split with no functional change.
- Bad: pre-commit / CI scope is broader than any single seam needs.
- Bad: requires discipline not to introduce cross-seam imports.

## Validation

In Phase 7, attempt the polyrepo split of `gitops/`. If lifted-out
repo builds and tests without edits, the seam held.

## Links

- README.md (top-level layout)
