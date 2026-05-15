#!/usr/bin/env bash
# Anonymisation scan back-stop.
#
# Concatenates the public structural .gitleaks.toml with the private
# ~/.config/sigma-platform/gitleaks-forbidden.toml (if present) and
# runs gitleaks against staged changes. If the private file is
# absent, structural rules still fire and a warning is printed.

set -euo pipefail

PUBLIC_CONFIG=".gitleaks.toml"
PRIVATE_CONFIG="${HOME}/.config/sigma-platform/gitleaks-forbidden.toml"

if [[ ! -f "${PUBLIC_CONFIG}" ]]; then
  echo "ERROR: ${PUBLIC_CONFIG} not found" >&2
  exit 1
fi

if [[ -f "${PRIVATE_CONFIG}" ]]; then
  TMP=$(mktemp -t sigma-gitleaks.XXXXXX)
  mv "${TMP}" "${TMP}.toml"
  TMP="${TMP}.toml"
  # shellcheck disable=SC2064
  trap "rm -f '${TMP}'" EXIT
  cat "${PUBLIC_CONFIG}" "${PRIVATE_CONFIG}" > "${TMP}"
  gitleaks protect --staged --redact --no-banner --config "${TMP}"
else
  echo "WARN: ${PRIVATE_CONFIG} not found — running structural rules only." >&2
  echo "      Copy ${PRIVATE_CONFIG}.template to ${PRIVATE_CONFIG}" >&2
  echo "      and populate with real forbidden tokens for full coverage." >&2
  gitleaks protect --staged --redact --no-banner --config "${PUBLIC_CONFIG}"
fi
