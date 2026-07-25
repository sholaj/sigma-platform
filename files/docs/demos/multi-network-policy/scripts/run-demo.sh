#!/usr/bin/env bash
#
# Multi-network policy isolation demo -- automated test harness.
#
# Walks the cluster through four states and asserts expected reachability at
# each one. Exits non-zero if any assertion fails, so it is usable as a gate
# in CI as well as a live demo driver.
#
# Tests are TCP-only by design: restricted-v2 drops NET_RAW, so pod ICMP fails
# with EPERM for reasons unrelated to policy. ICMP is demonstrated separately
# from the VMs -- see README.
#
# Usage:
#   ./run-demo.sh setup      Apply namespaces, NADs, probe pods. No policy.
#   ./run-demo.sh baseline   Assert the segment is wide open.
#   ./run-demo.sh deny       Apply default-deny, assert full isolation.
#   ./run-demo.sh allow      Apply selective allow, assert the exact flow.
#   ./run-demo.sh scope      Assert net-b is unaffected and default net is too.
#   ./run-demo.sh all        Run every phase in order.
#   ./run-demo.sh ips        Print the secondary interface addresses.
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}"
[[ -d "${ROOT}/.rendered" ]] && SRC="${ROOT}/.rendered"

PASS=0
FAIL=0
NC_TIMEOUT="${NC_TIMEOUT:-4}"

c_green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
c_red()   { printf '\033[0;31m%s\033[0m\n' "$1"; }
c_head()  { printf '\n\033[1;36m=== %s ===\033[0m\n' "$1"; }

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1"; exit 1; }
}
need oc
need jq

# --- helpers ---------------------------------------------------------------

# secondary_ip <namespace> <pod> <network-name>
# Reads the network-status annotation Multus writes back onto the pod.
secondary_ip() {
  local ns="$1" pod="$2" net="$3"
  oc get pod -n "${ns}" "${pod}" \
    -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}' 2>/dev/null \
    | jq -r --arg n "${net}" '.[] | select(.name | endswith($n)) | .ips[0] // empty' \
    | head -n1
}

# default_ip <namespace> <pod>
default_ip() { oc get pod -n "$1" "$2" -o jsonpath='{.status.podIP}' 2>/dev/null; }

# probe <label> <src-ns> <src-pod> <dst-ip> <port> <expect: PASS|FAIL>
probe() {
  local label="$1" ns="$2" pod="$3" ip="$4" port="$5" expect="$6"

  if [[ -z "${ip}" ]]; then
    c_red "  [ERROR] ${label} -- destination IP not resolved"
    FAIL=$((FAIL + 1)); return
  fi

  local actual="FAIL"
  if oc exec -n "${ns}" "${pod}" -- \
       timeout "${NC_TIMEOUT}" bash -c "</dev/tcp/${ip}/${port}" >/dev/null 2>&1; then
    actual="PASS"
  fi

  if [[ "${actual}" == "${expect}" ]]; then
    c_green "  [OK]   ${label} -> ${ip}:${port} = ${actual} (expected ${expect})"
    PASS=$((PASS + 1))
  else
    c_red   "  [BAD]  ${label} -> ${ip}:${port} = ${actual} (expected ${expect})"
    FAIL=$((FAIL + 1))
  fi
}

resolve_all() {
  DB_NETA="$(secondary_ip tenant-a probe-db net-a)"
  DB_NETB="$(secondary_ip tenant-a probe-db net-b)"
  DB_DEFAULT="$(default_ip tenant-a probe-db)"
  APP_NETA="$(secondary_ip tenant-b probe-app net-a)"
  ROGUE_NETA="$(secondary_ip tenant-c probe-rogue net-a)"
  DB_CUDN="$(secondary_ip tenant-a probe-db-cudn cudn-net)"
  APP_CUDN="$(secondary_ip tenant-b probe-app-cudn cudn-net)"
}

wait_ready() {
  echo "Waiting for probe pods..."
  oc wait --for=condition=Ready pod/probe-db    -n tenant-a --timeout=180s || true
  oc wait --for=condition=Ready pod/probe-app   -n tenant-b --timeout=180s || true
  oc wait --for=condition=Ready pod/probe-rogue -n tenant-c --timeout=180s || true
  echo "Allowing 30s for in-container package install and listeners to bind..."
  sleep 30
}

# --- phases ----------------------------------------------------------------

phase_preflight() {
  c_head "PREFLIGHT"
  local enabled
  enabled="$(oc get network.operator cluster -o jsonpath='{.spec.useMultiNetworkPolicy}' 2>/dev/null)"
  if [[ "${enabled}" == "true" ]]; then
    c_green "  [OK]   useMultiNetworkPolicy = true"
  else
    c_red   "  [BAD]  useMultiNetworkPolicy is '${enabled:-unset}'"
    c_red   "         Enable it and wait for the network rollout before continuing."
    exit 1
  fi

  if oc api-resources --api-group=k8s.cni.cncf.io 2>/dev/null | grep -q multi-networkpolicies; then
    c_green "  [OK]   MultiNetworkPolicy CRD present"
  else
    c_red   "  [BAD]  MultiNetworkPolicy CRD not found"
    exit 1
  fi
}

phase_setup() {
  c_head "SETUP"
  oc apply -f "${SRC}/manifests/00-namespaces.yaml"
  oc apply -f "${SRC}/manifests/10-nad-net-a.yaml"
  oc apply -f "${SRC}/manifests/11-nad-net-b.yaml"
  oc apply -f "${SRC}/manifests/12-nad-net-c.yaml"
  oc apply -f "${SRC}/manifests/20-probe-pods.yaml"
  wait_ready
  resolve_all
  phase_ips
}

phase_ips() {
  c_head "ADDRESSES"
  printf '  tenant-a/probe-db     net-a   %s\n' "${DB_NETA:-<none>}"
  printf '  tenant-a/probe-db     net-b   %s\n' "${DB_NETB:-<none>}"
  printf '  tenant-a/probe-db     default %s\n' "${DB_DEFAULT:-<none>}"
  printf '  tenant-b/probe-app    net-a   %s\n' "${APP_NETA:-<none>}"
  printf '  tenant-c/probe-rogue  net-a   %s\n' "${ROGUE_NETA:-<none>}"
}

phase_baseline() {
  c_head "PHASE 0 -- BASELINE (no policy: flat L2, namespaces mean nothing)"
  resolve_all
  probe "tenant-b/app  ->  tenant-a/db  :5432" tenant-b probe-app   "${DB_NETA}" 5432 PASS
  probe "tenant-b/app  ->  tenant-a/db  :8080" tenant-b probe-app   "${DB_NETA}" 8080 PASS
  probe "tenant-c/rogue->  tenant-a/db  :5432" tenant-c probe-rogue "${DB_NETA}" 5432 PASS
  echo "  Note: three separate namespaces, zero isolation. This is the 'before'."
}

phase_deny() {
  c_head "PHASE 1 -- DEFAULT DENY on net-a"
  oc apply -f "${SRC}/policies/00-deny-all-net-a.yaml"
  sleep 10
  resolve_all
  probe "tenant-b/app  ->  tenant-a/db  :5432" tenant-b probe-app   "${DB_NETA}" 5432 FAIL
  probe "tenant-b/app  ->  tenant-a/db  :8080" tenant-b probe-app   "${DB_NETA}" 8080 FAIL
  probe "tenant-c/rogue->  tenant-a/db  :5432" tenant-c probe-rogue "${DB_NETA}" 5432 FAIL
}

phase_allow() {
  c_head "PHASE 2 -- SELECTIVE ALLOW (tenant-b role=app -> tenant-a role=db :5432)"
  oc apply -f "${SRC}/policies/10-allow-app-to-db-5432.yaml"
  sleep 10
  resolve_all
  probe "tenant-b/app  ->  tenant-a/db  :5432" tenant-b probe-app   "${DB_NETA}" 5432 PASS
  probe "tenant-b/app  ->  tenant-a/db  :8080" tenant-b probe-app   "${DB_NETA}" 8080 FAIL
  probe "tenant-c/rogue->  tenant-a/db  :5432" tenant-c probe-rogue "${DB_NETA}" 5432 FAIL
  echo "  Port granularity and source granularity, on a flat VLAN."
}

phase_scope() {
  c_head "PHASE 3 -- SCOPE PROOF"
  resolve_all
  echo "  net-b carries no policy at all -- locking net-a must not touch it:"
  probe "tenant-b/app  ->  tenant-a/db  net-b:5432" tenant-b probe-app "${DB_NETB}" 5432 PASS
  echo
  echo "  Default pod network is a separate policy plane entirely:"
  probe "tenant-b/app  ->  tenant-a/db  default:5432" tenant-b probe-app "${DB_DEFAULT}" 5432 PASS
  echo
  echo "  Takeaway: MultiNetworkPolicy governs ONLY the annotated network."
  echo "  An audit that reviews NetworkPolicy alone has seen half the estate."
}

phase_cudn_setup() {
  c_head "CUDN SETUP -- namespace-selector attach model"
  oc apply -f "${SRC}/manifests/13-cudn-localnet.yaml"
  echo "Waiting for the CUDN controller to render NADs into selected namespaces..."
  local ok=1
  for ns in tenant-a tenant-b; do
    if oc get net-attach-def -n "${ns}" cudn-net >/dev/null 2>&1; then
      c_green "  [OK]   rendered NAD present: ${ns}/cudn-net"
    else
      # give the controller a moment, then re-check
      sleep 10
      if oc get net-attach-def -n "${ns}" cudn-net >/dev/null 2>&1; then
        c_green "  [OK]   rendered NAD present: ${ns}/cudn-net"
      else
        c_red "  [BAD]  ${ns}/cudn-net not rendered -- CUDN selector or name mismatch"
        c_red "         The policy-for annotations reference <ns>/cudn-net and will"
        c_red "         not bind. Inspect: oc get clusteruserdefinednetwork cudn-net -o yaml"
        ok=0
      fi
    fi
  done
  # Prove the namespace gate: tenant-c is NOT selected, so no NAD should exist.
  if oc get net-attach-def -n tenant-c cudn-net >/dev/null 2>&1; then
    c_red "  [BAD]  tenant-c/cudn-net exists but tenant-c should not be selected"
    ok=0
  else
    c_green "  [OK]   tenant-c NOT attached (namespace gate working as intended)"
  fi
  (( ok == 0 )) && { FAIL=$((FAIL+1)); return 1; }

  oc apply -f "${SRC}/manifests/22-probe-pods-cudn.yaml"
  oc wait --for=condition=Ready pod/probe-db-cudn  -n tenant-a --timeout=180s || true
  oc wait --for=condition=Ready pod/probe-app-cudn -n tenant-b --timeout=180s || true
  echo "Allowing 30s for listeners to bind..."
  sleep 30
  resolve_all
  printf '  tenant-a/probe-db-cudn   cudn-net  %s\n' "${DB_CUDN:-<none>}"
  printf '  tenant-b/probe-app-cudn  cudn-net  %s\n' "${APP_CUDN:-<none>}"
}

phase_cudn_baseline() {
  c_head "CUDN PHASE 0 -- BASELINE (attached via selector, no policy yet)"
  resolve_all
  probe "tenant-b/app-cudn -> tenant-a/db-cudn :5432" tenant-b probe-app-cudn "${DB_CUDN}" 5432 PASS
  echo "  Same wide-open L2 as net-a -- but these namespaces joined the VLAN by"
  echo "  matching the CUDN selector, not by a hand-written per-namespace NAD."
}

phase_cudn_deny() {
  c_head "CUDN PHASE 1 -- DEFAULT DENY (policy binds to the rendered NAD)"
  oc apply -f "${SRC}/policies/30-deny-all-cudn.yaml"
  sleep 10
  resolve_all
  probe "tenant-b/app-cudn -> tenant-a/db-cudn :5432" tenant-b probe-app-cudn "${DB_CUDN}" 5432 FAIL
}

phase_cudn_allow() {
  c_head "CUDN PHASE 2 -- SELECTIVE ALLOW (policy plane identical to net-a)"
  oc apply -f "${SRC}/policies/31-allow-app-to-db-cudn.yaml"
  sleep 10
  resolve_all
  probe "tenant-b/app-cudn -> tenant-a/db-cudn :5432" tenant-b probe-app-cudn "${DB_CUDN}" 5432 PASS
  probe "tenant-b/app-cudn -> tenant-a/db-cudn :8080" tenant-b probe-app-cudn "${DB_CUDN}" 8080 FAIL
  echo "  Attach model changed (selector vs per-pod); policy behaviour did not."
}

phase_cudn_gate() {
  c_head "CUDN -- NAMESPACE GATE DEMONSTRATION (optional, expected to fail-attach)"
  echo "  Attempting a pod in tenant-c (NOT selected by the CUDN)."
  cat <<'POD' | oc apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: probe-rogue-cudn
  namespace: tenant-c
  annotations:
    k8s.v1.cni.cncf.io/networks: '[{"name":"cudn-net","interface":"net1"}]'
spec:
  containers:
    - name: probe
      image: registry.access.redhat.com/ubi9/ubi:latest
      command: ["sleep","infinity"]
POD
  sleep 15
  local phase
  phase="$(oc get pod -n tenant-c probe-rogue-cudn -o jsonpath='{.status.phase}' 2>/dev/null)"
  if [[ "${phase}" != "Running" ]]; then
    c_green "  [OK]   tenant-c pod is '${phase:-absent}', not Running -- namespace gate held"
    echo "         Event:"
    oc get events -n tenant-c --field-selector involvedObject.name=probe-rogue-cudn \
      -o jsonpath='{range .items[*]}{.reason}: {.message}{"\n"}{end}' 2>/dev/null | grep -i network | head -2 | sed 's/^/           /'
  else
    c_red "  [BAD]  tenant-c pod is Running -- it should not have attached"
    FAIL=$((FAIL+1))
  fi
  oc delete pod -n tenant-c probe-rogue-cudn --ignore-not-found --wait=false >/dev/null 2>&1
}

phase_report() {
  c_head "RESULT"
  echo "  passed: ${PASS}   failed: ${FAIL}"
  if (( FAIL > 0 )); then
    c_red "  DEMO ASSERTIONS FAILED"
    echo
    echo "  Triage order:"
    echo "    1. Is the policy-for annotation present and pointing at <ns>/<nad>?"
    echo "    2. Did listeners actually bind?  oc exec -n tenant-a probe-db -- ss -lntp"
    echo "    3. Are namespaceSelector and podSelector under the SAME list item?"
    echo "    4. Did you restore Egress as well as Ingress after the default-deny?"
    echo "    5. CUDN only: did the controller render <ns>/cudn-net? oc get net-attach-def -A"
    return 1
  fi
  c_green "  ALL ASSERTIONS PASSED"
  return 0
}

# --- entrypoint ------------------------------------------------------------

case "${1:-all}" in
  setup)    phase_preflight; phase_setup ;;
  ips)      resolve_all; phase_ips ;;
  baseline) phase_baseline; phase_report ;;
  deny)     phase_deny; phase_report ;;
  allow)    phase_allow; phase_report ;;
  scope)    phase_scope; phase_report ;;
  cudn)     phase_cudn_setup && phase_cudn_baseline && phase_cudn_deny && phase_cudn_allow; phase_report ;;
  cudn-gate) phase_cudn_gate; phase_report ;;
  all)
    phase_preflight
    phase_setup
    phase_baseline
    phase_deny
    phase_allow
    phase_scope
    phase_cudn_setup
    phase_cudn_baseline
    phase_cudn_deny
    phase_cudn_allow
    phase_report
    ;;
  *)
    echo "Usage: $0 {setup|baseline|deny|allow|scope|cudn|cudn-gate|ips|all}"
    exit 2
    ;;
esac
