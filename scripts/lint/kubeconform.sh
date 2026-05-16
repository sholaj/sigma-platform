#!/usr/bin/env bash
# kubeconform schema validation across gitops/, clusters/, policies/.
# Used by both `task lint:kubeconform` (lenient) and `task validate:strict`
# via the --strict flag.

set -euo pipefail

KUBE_VERSION="${KUBE_VERSION:-1.30.0}"
SCHEMA_CATALOG='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
LOCAL_SCHEMAS='schemas/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

STRICT_FLAG="-ignore-missing-schemas"
if [ "${1:-}" = "--strict" ]; then
  STRICT_FLAG=""
  echo "Running in STRICT mode (missing schemas are fatal)."
fi

# Manifest discovery — only validate dirs that have content.
dirs=()
for d in gitops clusters policies; do
  if [ -d "$d" ] && find "$d" \( -name '*.yaml' -o -name '*.yml' \) -type f -print -quit | grep -q .; then
    dirs+=("$d")
  fi
done

if [ ${#dirs[@]} -eq 0 ]; then
  echo "No manifests under gitops/, clusters/, or policies/ — nothing to validate."
  exit 0
fi

# Build the file list, excluding clusters/baremetal-reference (those are
# reference artefacts that may use CRDs not in the catalogue).
mapfile -t files < <(find "${dirs[@]}" \( -name '*.yaml' -o -name '*.yml' \) -type f \
  | grep -v '^clusters/baremetal-reference/')

if [ ${#files[@]} -eq 0 ]; then
  echo "No applicable manifests after exclusions — nothing to validate."
  exit 0
fi

# shellcheck disable=SC2086
kubeconform \
  -strict \
  $STRICT_FLAG \
  -kubernetes-version "$KUBE_VERSION" \
  -schema-location default \
  -schema-location "$SCHEMA_CATALOG" \
  -schema-location "$LOCAL_SCHEMAS" \
  -summary \
  -output text \
  "${files[@]}"
