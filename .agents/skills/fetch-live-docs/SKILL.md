---
name: fetch-live-docs
description: |
  ALWAYS use this skill BEFORE generating OpenShift, OpenShift
  Virtualization, MTV, Cilium, ACM, ArgoCD, KubeVirt, Forklift, ARO, or
  Azure CLI configuration, manifests, CRDs, or commands. Use whenever
  the user asks for a YAML manifest, a Helm value, a CRD spec, an oc/az
  command, or any version-pinned config. Use this skill even if you
  think you remember the answer — model training data lags behind these
  fast-moving stacks and silently-wrong YAML is the biggest failure mode
  on this project.
---

# Fetch live documentation before configuring

You MUST NOT generate manifests from memory for the stacks listed below.
Training data for OpenShift / Cilium / Azure changes monthly. Wrong API
versions, removed Helm values, and deprecated CRD fields are the most
common bugs in agent-generated platform code.

## Canonical sources (use WebFetch with these exact root URLs)

| Stack                              | Root URL                                                                          |
|------------------------------------|-----------------------------------------------------------------------------------|
| OpenShift Container Platform 4.20  | https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/        |
| OpenShift Virtualization (4.20)    | https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/virtualization/index |
| MTV / Forklift                     | https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/    |
| Cilium 1.19                        | https://docs.cilium.io/en/v1.19/                                                  |
| Isovalent OLM for Cilium           | https://github.com/isovalent/olm-for-cilium                                       |
| ACM (current)                      | https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/ |
| ArgoCD                             | https://argo-cd.readthedocs.io/en/stable/                                          |
| KubeVirt upstream                  | https://kubevirt.io/user-guide/                                                   |
| Azure Red Hat OpenShift            | https://learn.microsoft.com/en-us/azure/openshift/                                |
| `az aro` CLI reference             | https://learn.microsoft.com/en-us/cli/azure/aro                                   |
| OpenShift Virt on ARO              | https://learn.microsoft.com/en-us/azure/openshift/howto-create-openshift-virtualization |

## Workflow

1. Identify which stack(s) the user's task touches.
2. Use WebFetch on the specific page (not the root) for each stack
   touched. Prefer the version-pinned URL (e.g. `/4.20/` not `/latest/`).
3. Quote the docs in the PR description and ADR with the fetched URL.
4. If WebFetch fails (network, sandbox), STOP and tell the user.
   Do not fall back to training data — say "I cannot generate this
   without fetching the current docs" and ask the user to authorise
   the fetch.
5. Pin specific versions in every manifest:
   - OpenShift: 4.20
   - Cilium: 1.19.x (state the exact patch chosen)
   - ACM: state the version
6. When the docs page describes multiple options, ask the user which
   path before generating.

## What "live" means here

"Live" means: the page returned by WebFetch in this session, not what
you remember. A previous fetched page from earlier in the conversation
counts as live for the next ~30 minutes; after that, re-fetch.
