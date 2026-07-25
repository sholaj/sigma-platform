# Multi-network policy isolation demo

Demonstrates east-west isolation across namespaces on OVN-Kubernetes secondary
networks, using `MultiNetworkPolicy`. Built as a teaching artifact for a team
transitioning from a VMware NSX operational background.

## Why this exists

On the default pod network, namespaces are already a soft boundary and standard
`NetworkPolicy` works. On a **flat localnet VLAN, namespaces mean nothing** —
every pod and VM attached to the segment can reach every other one regardless of
namespace, because it is just L2. That is the "before" state, and it is the part
that lands with a network-engineering audience: the VLAN is the old flat segment,
`MultiNetworkPolicy` is the distributed firewall.

The second, less obvious point the demo proves: **`MultiNetworkPolicy` governs
only the network named in its annotation, and standard `NetworkPolicy` governs
only the default network.** Neither sees the other. A security review that
inspects `NetworkPolicy` alone has inspected half the estate. That is worth
establishing now, before the pattern is replicated at scale.

## Applicability

| | |
|---|---|
| CNI | OVN-Kubernetes only |
| Cluster | Playground / hub-style clusters |
| **Not applicable to** | The Cilium-based virtualization cluster — use `CiliumNetworkPolicy` there |

`MultiNetworkPolicy` is an OVN-Kubernetes construct. It does not exist on
Cilium clusters. Neither does `UserDefinedNetwork` / `ClusterUserDefinedNetwork`.
Do not carry this pattern across to the workload cluster; the equivalent
capability there is `CiliumNetworkPolicy`, which is a richer object with
identity-based rather than IP-based enforcement.

## Layout

```text
docs/demos/multi-network-policy/
├── README.md
├── copilot-instructions.md      Generic generator instruction (spec-driven)
├── values.env                   Placeholder -> site-real mapping (local only)
├── manifests/
│   ├── 00-namespaces.yaml       tenant-a, tenant-b, tenant-c
│   ├── 01-nncp-bridge-mapping.yaml   REFERENCE ONLY — do not apply blind
│   ├── 10-nad-net-a.yaml        Shared segment, one NAD per namespace
│   ├── 11-nad-net-b.yaml        Control segment, deliberately unpoliced
│   ├── 12-nad-net-c.yaml        Third segment, VM ICMP demo
│   ├── 20-probe-pods.yaml       Automated test subjects
│   ├── 21-vms-rhel9.yaml        RHEL 9 VMs, human-facing demo
│   └── 30-scc-net-raw.yaml      OPTIONAL — only if pod ICMP is required
├── policies/
│   ├── 00-deny-all-net-a.yaml
│   ├── 10-allow-app-to-db-5432.yaml
│   ├── 11-allow-app-to-db-ipblock.yaml   Alternative to 10-
│   ├── 12-allow-icmp-vm.yaml
│   ├── 20-netpol-default-network.yaml    Standard NetworkPolicy, for contrast
│   ├── 30-deny-all-cudn.yaml             Default-deny on the CUDN network
│   └── 31-allow-app-to-db-cudn.yaml      Selective allow on the CUDN network
└── scripts/
    ├── render.sh                Placeholder -> real substitution
    ├── run-demo.sh              Phased test harness
    └── teardown.sh
```

## Two attach models, side by side

The demo carries **both** ways to put a namespace onto a localnet VLAN, on
separate VLANs so they run simultaneously without colliding.

**Raw NAD (net-a/b/c).** You author one `NetworkAttachmentDefinition` per
namespace. Attachment is per *pod*: a workload joins by carrying the
`k8s.v1.cni.cncf.io/networks` annotation. The namespace has no VLAN hook — its
only jobs are to scope the NAD and to be a policy selector target. Any pod in a
namespace that holds the NAD can attach; there is no namespace-level gate.

**CUDN (cudn-net).** A single cluster-scoped `ClusterUserDefinedNetwork`
selects namespaces by label (`cudn-attach: "true"`). The controller renders a
NAD named after the CUDN into each selected namespace. This is the declarative
"attach the namespace to the VLAN" model: label the namespace, it is attached;
omit the label, it is not. tenant-c deliberately lacks the label, so a pod
there referencing `cudn-net` fails to attach — the namespace gate in action.
Workloads still opt in with the same `networks` annotation, referencing the
rendered NAD name.

The payoff is that **the policy plane is identical across both.** A
`MultiNetworkPolicy` binds via `policy-for: <namespace>/<nad-name>` either way
— for the CUDN, the rendered NAD name equals the CUDN name (`cudn-net`). Run
`scripts/run-demo.sh cudn` after the main run and you get the same deny → allow
behaviour, proving the attach mechanism and the enforcement mechanism are
independent concerns.

One caveat worth stating to the team: `MultiNetworkPolicy` selector support on
a secondary network depends on whether the network defines `subnets`. This CUDN
defines them, so pod and namespace selectors work exactly as on net-a. A
*subnetless* CUDN — which you would reach for to maximise VM live-migration
flexibility — narrows you toward ipBlock-style rules. That trade-off is a real
decision for the virtualization-cluster build, not just a demo detail.

## Running it

```bash
# 1. Map placeholders to your real VLAN IDs and subnets (local only).
cp values.env values.env.local   # edit the *_REAL entries
./scripts/render.sh              # writes ./.rendered/, which is gitignored

# 2. Run phase by phase, narrating between each.
./scripts/run-demo.sh setup
./scripts/run-demo.sh baseline   # wide open — the "before"
./scripts/run-demo.sh deny       # total isolation
./scripts/run-demo.sh allow      # one flow, one port, one source
./scripts/run-demo.sh scope      # per-network scoping + plane independence

# Or end to end, as a CI gate:
./scripts/run-demo.sh all
```

`run-demo.sh` exits non-zero on any failed assertion, so it doubles as a
regression test rather than only a presentation script.

## Test matrix

| Phase | Assertion | Proves |
|---|---|---|
| 0 | All three namespaces reach `db:5432` and `db:8080` on net-a | Namespaces are not a boundary on a flat VLAN |
| 1 | All flows on net-a fail | Default-deny works per network |
| 2 | tenant-b app → db:5432 passes; :8080 fails; tenant-c fails | Source *and* port granularity |
| 3 | net-b unaffected | Policies are scoped to the annotated NAD |
| 3 | Default pod network unaffected | The two policy planes are independent |

Phases 0–2 show that a firewall works. Phase 3 is the one that changes how
people design. Do not cut it for time.

## Things that will break the demo

**The `policy-for` annotation.** `k8s.v1.cni.cncf.io/policy-for: <ns>/<nad>` is
what binds a policy to a network. Omit it and the object applies cleanly and
does nothing at all. This is the single most common failure.

**Selector AND vs OR.** `namespaceSelector` and `podSelector` under the *same*
list item mean AND. Under separate `-` items they mean OR, which silently
widens the rule to every pod in the namespace plus every matching pod
everywhere. Check the indentation before blaming OVN.

**Egress after a default-deny.** `00-deny-all-net-a.yaml` denies both
directions. Restoring a flow needs an ingress rule on the destination *and* an
egress rule on the source. Ingress alone leaves the flow broken and looks like
a bug.

**firewalld on the RHEL 9 VMs.** The stock template runs firewalld with only
SSH open. A test against 5432 fails while the policy permits it. The cloud-init
in `21-vms-rhel9.yaml` disables it. Prove connectivity end to end *before*
applying any policy, so the baseline is trustworthy.

**Pod ICMP.** `restricted-v2` drops `NET_RAW`, so ping from a pod fails with
EPERM regardless of network policy — a false negative that looks exactly like a
policy denial. Scripted tests are TCP-only. Demonstrate ICMP from the VMs,
where the guest kernel owns its own raw sockets. `30-scc-net-raw.yaml` exists
if pod ICMP is genuinely needed.

**ICMP has no protocol field.** The mechanism is indirect: a rule with a `from`
block and *no* `ports` block permits all protocols including ICMP. Add a
`ports` stanza and ICMP stops immediately while the named TCP port survives.
Demonstrate this deliberately — it is the clearest way to show these are L3/L4
constructs, not stateful firewall rules.

**Enforcement point.** On `ovn-k8s-cni-overlay` secondary networks the rules
land as OVN ACLs. On macvlan and SR-IOV NADs the implementation is iptables
inside the pod network namespace, which interacts poorly with bridge-bound VM
interfaces. Keep VM demos on localnet NADs.

## Regenerating or extending

`copilot-instructions.md` is a *generator*, not a driver for this demo
specifically. Feed it a topology SPEC — tenants, networks, VLANs, subnets,
listen ports, allow rules — and it produces a complete equivalent demo under
`docs/demos/<demoName>/`, including the harness and the validation gate.

It encodes the failure modes that make these demos silently wrong: the missing
`policy-for` annotation, `netAttachDefName` divergence, selector AND vs OR,
ingress-without-egress after a default-deny, and pod ICMP under `restricted-v2`.
Those are the parts worth version-controlling. Use the short variant at the end
of that file to add a tenant or a network without hand-patching.

## Sanitisation

Committed manifests carry **placeholder** VLAN IDs (100/101/102) and subnets
(10.100.0.0/24, 10.101.0.0/24, 10.102.0.0/24), plus a generic
`physicalNetworkName` of `physnet`. Site-real values are supplied locally via
`values.env` and applied by `render.sh` into `.rendered/`, which is gitignored.
This follows the same convention already used for BGP ASNs.

Do not commit `.rendered/`. Do not replace the placeholders in-place. The
`gitleaks` pre-commit hook will not catch a VLAN ID — this one is on review
discipline.

The cloud-init password in `21-vms-rhel9.yaml` is a throwaway literal for an
isolated playground. Replace it with a secret reference before this pattern is
reused anywhere that outlives a demo.
