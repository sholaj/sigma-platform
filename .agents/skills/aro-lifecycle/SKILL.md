---
name: aro-lifecycle
description: |
  Use this skill for ANY Azure Red Hat OpenShift (ARO) provisioning,
  teardown, scaling, or cost work. Use when the user mentions `az aro`,
  ARO cluster sizing, Dsv5/Dsv6 instance families, ARO pull secrets,
  nested virtualization on ARO, or the daily spin-up/spin-down workflow.
  This skill MUST be used before running anything that costs money on
  Azure.
---

# ARO lifecycle on uksouth — cost-aware, on-demand

## Hard facts (verify with fetch-live-docs every session)

- `az aro` CLI exposes `create`, `delete`, `update`, `list-credentials`,
  `get-admin-kubeconfig`, `restart` — but NO `stop`/`start` as of the
  Azure CLI v2.x ARO module. The ONLY zero-cost state is `delete`.
- Minimum supported worker VM family on ARO is Dsv5/Dsv6 with >=8 cores
  for OpenShift Virtualization. For non-virt clusters Standard_D8s_v3
  is the smallest validated worker (8 vCPU / 32 GiB) — on-demand
  list pricing roughly $0.38/hr per VM (≈£0.30/hr) in uksouth.
- ARO requires 3 control plane + 3 worker minimum.

## Cost discipline rules (solo, one cluster at a time)

1. **Only one ARO cluster runs at any time.** Hub OR virt, never both.
   When switching, tear down first and verify the RG is gone before
   spinning up the other.
2. NEVER leave a cluster running overnight. Always destroy at end of
   working session.
3. Tag every resource group with `project=sigma-platform`,
   `cost-owner=sholaj`, `auto-destroy=true`, `created=<ISO date>`.
4. Single Azure subscription with a £500 monthly budget and alerts at
   50% / 80% / 100%.
5. For KubeVirt experiments, prefer LOCAL kind clusters.
6. For ACM multi-cluster patterns, the spoke is a LOCAL kind cluster.

## Spin-up

Always via `task aro:up:hub` or `task aro:up:virt`. These wrap
`terraform apply` with the correct workspace, the
`assert-none-running` guard, and a confirmation prompt.

## Tear-down

Always via `task aro:down:all`. This:

1. Runs `terraform destroy` against each workspace
2. Falls back to `az group delete --yes --no-wait` on the
   per-cluster RG and the ARO-managed RG (`aro-<domain>`) if state
   is corrupt
3. Verifies the RG is GONE before exiting

## Known gotchas

- `az aro delete` can hit InternalServerError if Azure Private Link
  services or NSG attachments dangle. Always check the managed RG
  (`aro-<clusterProfile.domain>`) for orphans BEFORE running
  `az group delete`.
- The Microsoft.RedHatOpenShift resource provider must be registered:
  `az provider register --namespace Microsoft.RedHatOpenShift`
- Cluster creation takes 35–45 min. Destruction takes 30–40 min.
- Service principal credentials in the ARO cluster expire after a year.
  For this lab they are recreated each spin-up, so this is moot.
