#!/usr/bin/env bash
# kube-linter best-practice checks across gitops/, clusters/, policies/.

set -euo pipefail

# Manifest discovery — match kubeconform.sh's logic so the two stay aligned.
dirs=()
for d in gitops clusters policies; do
  if [ -d "$d" ] && find "$d" \( -name '*.yaml' -o -name '*.yml' \) -type f -print -quit | grep -q .; then
    dirs+=("$d")
  fi
done

if [ ${#dirs[@]} -eq 0 ]; then
  echo "No manifests under gitops/, clusters/, or policies/ — nothing to lint."
  exit 0
fi

# Exclude clusters/baremetal-reference — those are reference artefacts, not
# deployable today.
kube-linter lint \
  --config .kube-linter.yaml \
  "${dirs[@]}"
