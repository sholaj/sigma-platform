---
name: yaml-validate
description: |
  ALWAYS use this skill before staging or committing any YAML file
  (Kubernetes manifests, Kustomize bases/overlays, Helm values,
  ArgoCD Applications, ACM Policies, GitHub Actions workflows, ARO
  install-config, Cilium CiliumConfig). Use when the user pastes raw
  YAML for review. Use as part of a "pre-commit" review of any diff
  that touches *.yaml or *.yml.
---

# YAML validation pipeline

Run these checks in order. Stop on first failure. Report exact line
numbers.

## 1. Syntax (yamllint)

`yamllint -c .yamllint.yaml <file>`

## 2. Kubernetes schema (kubeconform)

```bash
kubeconform \
  -strict \
  -ignore-missing-schemas \
  -kubernetes-version 1.30.0 \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -summary <file>
```

## 3. Kustomize build before apply

`kustomize build <overlay> | kubeconform -strict -summary -`

## 4. Best-practice linter (kube-linter)

`kube-linter lint <file_or_dir>`

## 5. Server-side dry-run (only if a live cluster is available)

`oc apply --dry-run=server -f <file>`

This is the ONLY check that catches admission-controller-level rejects
(quota, PSA, OPA/Kyverno policies). Do not skip when an ARO cluster
is up.

## Output contract

Emit a single summary block:

```text
yamllint:    OK / N issues
kubeconform: OK / N issues
kube-linter: OK / N issues
server-side: OK / N issues / SKIPPED (no cluster)
```
