---
applyTo: "**/*.yaml,**/*.yml"
---
- Pin `apiVersion` precisely. Never use `latest` or unspecified.
- Always include `metadata.labels`:
    app.kubernetes.io/name
    app.kubernetes.io/part-of: sigma-platform
    app.kubernetes.io/managed-by: argocd
- Always set resource requests AND limits on Pod/Container specs.
- Never use `hostNetwork: true` outside of CNI components.
- Never hard-code namespaces; use Kustomize overlays or ArgoCD
  destination namespaces.
- For OpenShift, prefer `Route` over `Ingress`.
- For OpenShift, target the `restricted-v2` SCC unless explicitly
  justified in an ADR.
- For ARO targets, use standard `networking.k8s.io/v1 NetworkPolicy`.
  Use `CiliumNetworkPolicy` only in `clusters/baremetal-reference/`
  or in kind manifests.
