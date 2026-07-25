#!/usr/bin/env bash
# Rewrite placeholder VLAN IDs / subnets into site-real values.
#
# Committed manifests carry neutral placeholders so the repo stays free of
# site-identifying network detail. This renders them to ./.rendered/, which is
# gitignored. Never commit .rendered/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/.rendered"

# shellcheck source=/dev/null
source "${ROOT}/values.env"

rm -rf "${OUT}"
mkdir -p "${OUT}/manifests" "${OUT}/policies"

for f in "${ROOT}"/manifests/*.yaml "${ROOT}"/policies/*.yaml; do
  rel="${f#"${ROOT}"/}"
  sed \
    -e "s/\"vlanID\": ${NET_A_VLAN_PLACEHOLDER}/\"vlanID\": ${NET_A_VLAN_REAL}/g" \
    -e "s/\"vlanID\": ${NET_B_VLAN_PLACEHOLDER}/\"vlanID\": ${NET_B_VLAN_REAL}/g" \
    -e "s/\"vlanID\": ${NET_C_VLAN_PLACEHOLDER}/\"vlanID\": ${NET_C_VLAN_REAL}/g" \
    -e "s/id: ${NET_CUDN_VLAN_PLACEHOLDER}/id: ${NET_CUDN_VLAN_REAL}/g" \
    -e "s|${NET_A_PREFIX_PLACEHOLDER}|${NET_A_PREFIX_REAL}|g" \
    -e "s|${NET_B_PREFIX_PLACEHOLDER}|${NET_B_PREFIX_REAL}|g" \
    -e "s|${NET_C_PREFIX_PLACEHOLDER}|${NET_C_PREFIX_REAL}|g" \
    -e "s|${NET_CUDN_PREFIX_PLACEHOLDER}|${NET_CUDN_PREFIX_REAL}|g" \
    -e "s|\"physicalNetworkName\": \"${PHYSNET_PLACEHOLDER}\"|\"physicalNetworkName\": \"${PHYSNET_REAL}\"|g" \
    "${f}" > "${OUT}/${rel}"
done

echo "Rendered to ${OUT}"
