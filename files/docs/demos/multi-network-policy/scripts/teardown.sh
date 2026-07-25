#!/usr/bin/env bash
# Remove every object this demo creates.
set -uo pipefail

echo "Deleting demo namespaces (this removes VMs, DataVolumes, pods, NADs and policies)..."
for ns in tenant-a tenant-b tenant-c; do
  oc delete namespace "${ns}" --ignore-not-found --wait=false
done

echo "Deleting the cluster-scoped ClusterUserDefinedNetwork (not namespaced --"
echo "it is NOT removed by deleting the namespaces):"
oc delete clusteruserdefinednetwork cudn-net --ignore-not-found --wait=false
echo
echo "Optional SCC (left in place unless you remove it):"
echo "  oc delete scc restricted-v2-netraw --ignore-not-found"
echo
echo "The NNCP is NOT removed -- bridge mappings are usually shared cluster"
echo "infrastructure. Remove deliberately if this demo created it:"
echo "  oc delete nncp mnp-demo-localnet-mapping"
