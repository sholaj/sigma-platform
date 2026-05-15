---
name: openshift-virt-migration
description: |
  Use this skill whenever the user mentions migrating VMs from VMware
  ESXi / vSphere to OpenShift Virtualization, MTV, Forklift, vSphere
  providers, VDDK, warm migration, cold migration, NetworkMap,
  StorageMap, or virt-v2v. Use for any work in the clusters/virt/ or
  gitops/apps/mtv/ paths. Use this BEFORE writing MTV Plan CRs or
  Provider CRs — the MTV API surface changes between minor versions.
---

# OpenShift Virtualization migration patterns

Context: ~30 VMs are being migrated from VMware ESXi (with Cisco ACI
underlay on the source side) to OpenShift Virtualization on bare metal,
with Isovalent Cilium 1.19 as the CNI. This repo SIMULATES the
patterns on ARO and on local kind clusters. ARO does NOT support
running KubeVirt VMs unless the worker nodes are Dsv5/Dsv6 instance
types (8+ cores) which are the only ARO instance families that expose
nested virt — and even then it is a "self-managed add-on" with
documented constraints. See
https://learn.microsoft.com/en-us/azure/openshift/howto-create-openshift-virtualization

## Before writing any MTV manifest

1. Invoke fetch-live-docs.
2. Fetch the MTV current release docs:
   https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/
3. Confirm with the user:
   - Source provider type: `vsphere` (vCenter) or `esxi`?
   - VDDK image: where is it hosted (private registry)?
   - Migration type: `cold` (default) or `warm`?
   - StorageMap: source datastores → target StorageClass mapping?
   - NetworkMap: vSphere portgroups → multus NetworkAttachmentDefinitions?

## Anonymisation reminder

NEVER write real vCenter hostnames, real datastore names, real
portgroup names. Use:

- vCenter endpoint: `vcenter.example.com`
- Datastore: `datastore-01`, `datastore-02`, ...
- Portgroup: `pg-app-tier`, `pg-db-tier`, ...
- VM names: `app-vm-01` through `app-vm-30`

## Required CRs and order of creation

1. `Provider` (source) — vSphere endpoint
2. `Provider` (target) — auto-created, references the host cluster
3. `NetworkMap`
4. `StorageMap`
5. `Plan` — references the two providers and the two maps
6. `Migration` — references the Plan

Always include `--dry-run=client` validation as a Taskfile target
before applying.

## Known gotchas

- VM names must be lowercase and DNS-compliant. MTV will silently
  skip VMs with uppercase names.
- A VM with N VMDKs needs N PVCs. Mismatched counts leave the plan
  stuck at "Not ready".
- Change-Block-Tracking (CBT) must be enabled on the source VMs for
  warm migration.
- The VDDK init image MUST be available to MTV worker pods.
- IP/MAC preservation: MAC addresses are preserved by default,
  IPs are NOT — design the NetworkMap accordingly.
