---
applyTo: "docs/demos/**"
---

# Copilot instruction — secondary-network isolation demo generator

Generic. Give it a topology spec and it produces a complete, self-validating
`MultiNetworkPolicy` demonstration from nothing: namespaces, NADs, workloads,
policies, a phased test harness, sanitisation scaffolding and a README.

Paste the block below into Copilot Chat in agent mode from the repository root,
having first filled in the SPEC. It can also live at
`.github/instructions/secondary-network-demo.instructions.md`, where the
frontmatter above scopes it automatically.

Treat this file as production code: PR-reviewed, versioned, updated the moment
the platform's networking decisions change. A stale instruction file is worse
than none — it drives the agent confidently into the wrong cluster state.

---

## Copy-paste block

```text
ROLE
Generate a complete, runnable network-isolation demonstration for an
OVN-Kubernetes OpenShift cluster from the SPEC below. Create every artifact
from scratch. Do not assume any file already exists, and do not copy from
another demo directory without re-deriving it against this SPEC.

STOP CONDITION
If the SPEC still contains <ANGLE_BRACKET> placeholders, or is absent, ask me
to complete it. Do not guess namespaces, VLAN IDs, subnets or allow rules.
A guessed value produces a demo that applies cleanly and proves nothing, which
is worse than an error.

SPEC
  demoName: <short-kebab-name>
  physicalNetworkName: physnet
  probeImage: registry.access.redhat.com/ubi9/ubi:latest
  osDataSource: openshift-virtualization-os-images/rhel9
  tenants:
    - <namespace-1>
    - <namespace-2>
    - <namespace-3>
  networks:
    - name: <net-1>
      vlan: <id>
      subnet: <cidr>
      gateway: <ip>
      attachModel: nad          # nad = per-pod attach | cudn = namespace-selector attach
      attachedTo: [<namespace-1>, <namespace-2>, <namespace-3>]
      policed: true
    - name: <net-2>
      vlan: <id>
      subnet: <cidr>
      gateway: <ip>
      attachModel: nad
      attachedTo: [<namespace-1>, <namespace-2>]
      policed: false
    - name: <net-3>
      vlan: <id>
      subnet: <cidr>
      gateway: <ip>
      attachModel: cudn         # cluster-scoped CUDN, selects attachedTo namespaces by label
      attachedTo: [<namespace-1>, <namespace-2>]
      policed: true
  workloads:
    pods: true
    vms: true
  listenPorts: [<allowed-port>, <denied-port>]
  allowRules:
    - from: { namespace: <namespace-2>, labels: { <key>: <value> } }
      to:   { namespace: <namespace-1>, labels: { <key>: <value> } }
      ports: [<allowed-port>]

GENERATE
  docs/demos/<demoName>/
  ├── README.md
  ├── values.env
  ├── .gitignore                     must contain: .rendered/
  ├── manifests/
  │   ├── 00-namespaces.yaml
  │   ├── 10-nad-<net>.yaml          one file per network in SPEC
  │   ├── 20-probe-pods.yaml         if workloads.pods
  │   ├── 21-vms.yaml                if workloads.vms
  │   └── 30-scc-net-raw.yaml        always, marked OPTIONAL
  ├── policies/
  │   ├── 00-deny-all-<net>.yaml     policed networks only
  │   ├── 10-allow-<n>.yaml          one per allowRule
  │   ├── 11-allow-<n>-ipblock.yaml  CIDR-form alternative to each
  │   ├── 12-allow-all-protocols.yaml
  │   └── 20-netpol-default-network.yaml
  └── scripts/
      ├── render.sh
      ├── run-demo.sh
      └── teardown.sh

GENERATION RULES

NADs
- Emit one NetworkAttachmentDefinition object per (network x attachedTo
  namespace). Namespaces do not share a NAD object.
- The "name" field inside the CNI config must be IDENTICAL across every object
  for that network. That is what places them on one logical segment.
- "netAttachDefName" must equal that object's own <namespace>/<name>. It
  differs per object even though "name" does not. Getting these backwards is
  the most common structural error.
- Use type ovn-k8s-cni-overlay with topology localnet. Set physicalNetworkName
  from SPEC. Set excludeSubnets to the gateway as a /32.
- Every other field must be byte-identical across the objects for one network.

CUDN networks (attachModel: cudn)
- Emit ONE cluster-scoped ClusterUserDefinedNetwork (apiVersion k8s.ovn.org/v1),
  not a per-namespace object. spec.network.topology Localnet; spec.network.localnet
  with role Secondary, physicalNetworkName from SPEC, vlan.mode Access with the
  SPEC vlan id, subnets from SPEC, excludeSubnets the gateway /32, ipam.mode Enabled.
- Attach namespaces via spec.namespaceSelector.matchLabels. Add that same label to
  exactly the attachedTo namespaces in 00-namespaces.yaml, and to NO others.
- Do NOT also emit a raw NAD for a cudn network. The controller renders the NAD.
- The rendered NAD is named after the CUDN. MultiNetworkPolicy for a cudn network
  therefore uses policy-for: <namespace>/<cudn-name>. Verify this by asserting the
  rendered NAD exists before applying policy — do not assume the render succeeded.
- Workloads still attach with the k8s.v1.cni.cncf.io/networks annotation referencing
  the CUDN name. A pod in a namespace the CUDN does not select will fail to attach;
  if the SPEC wants to demonstrate that gate, place one probe in an unselected
  namespace and assert it does NOT reach Running.
- Define subnets on the CUDN so pod/namespace-selector policies are supported. If a
  SPEC explicitly requests a subnetless (live-migration-optimised) cudn network,
  restrict its generated policies to ipBlock form and say so in the README.
- vlan id MUST be unique across all localnet networks on the same physicalNetworkName,
  cudn and nad alike. Two networks sharing a vlan id break OVN-Kubernetes.

Policies
- Every MultiNetworkPolicy carries
    k8s.v1.cni.cncf.io/policy-for: <namespace>/<nad-name>
  referencing the NAD object in ITS OWN namespace, not the shared logical
  network name. Without this the object applies successfully and does nothing.
  If you emit a policy without it, that is a defect, not a style choice.
- Default-deny: for each policed network, one policy per attached namespace,
  podSelector {}, policyTypes [Ingress, Egress].
- Allow rules: because the default-deny covered both directions, each allowRule
  needs TWO objects — an Ingress policy in the destination namespace AND an
  Egress policy in the source namespace. Emitting ingress alone leaves the flow
  broken and looks like a platform bug.
- In a from/to block, namespaceSelector and podSelector under the SAME list
  item mean AND. Under separate "-" items they mean OR, silently widening the
  rule to every pod in the namespace plus every matching pod cluster-wide.
  Emit the AND form and add a comment saying so.
- Select namespaces with kubernetes.io/metadata.name where possible.
- ipblock variant: same intent expressed as a CIDR with an except list. Header
  comment must state that it is an alternative to the selector form and that
  exactly one of the two should be applied.
- 12-allow-all-protocols.yaml: a rule with a "from" block and NO "ports" block.
  Comment must explain that this is the only way to permit ICMP, because these
  objects have no protocol field, and that adding a ports stanza kills ICMP
  while leaving the named TCP port working.
- 20-netpol-default-network.yaml is a STANDARD networking.k8s.io/v1
  NetworkPolicy, not a MultiNetworkPolicy. It exists solely to demonstrate that
  the two policy planes are blind to each other.

Workloads
- Probe pods: attach via the k8s.v1.cni.cncf.io/networks annotation, one entry
  per network the namespace is attached to, with explicit interface names.
  Listen on every port in listenPorts. Bootstrap nmap-ncat and iproute at
  container start if absent.
- VMs: labels go on spec.template.metadata.labels, NOT on the VirtualMachine
  object. MultiNetworkPolicy selects the virt-launcher pod and only template
  labels reach it. Labelling the VM object achieves nothing.
- VM cloud-init must stop and disable firewalld before starting listeners. The
  stock RHEL image opens SSH only, so a test against any other port fails while
  the policy permits it.
- Do not install a real database or application server. These objects match on
  port number and have no protocol awareness; a bare ncat listener is a more
  reliable and faster-booting test subject.
- Any credential in cloud-init is a throwaway literal for an isolated lab.
  Flag it in the README as requiring a secret reference before reuse.

Scripts
- render.sh: sed-based substitution of placeholder VLAN IDs and subnet prefixes
  into ./.rendered/, driven by values.env. Never rewrite committed files in
  place.
- run-demo.sh: phased — preflight, setup, baseline, deny, allow, scope, report.
  Each phase asserts expected reachability and prints a pass/fail line per
  probe. Exit non-zero if any assertion fails so it doubles as a CI gate.
  Resolve secondary IPs from the pod's k8s.v1.cni.cncf.io/network-status
  annotation via jq; do not hardcode addresses.
  Use TCP tests only (bash /dev/tcp or nc). See INVARIANT 5.
- teardown.sh: delete the demo namespaces. Do NOT delete shared cluster
  infrastructure such as bridge mappings or SCCs without an explicit prompt.
- All scripts: set -uo pipefail, and pass bash -n.

INVARIANTS — verify each before reporting done
1. Every MultiNetworkPolicy has a policy-for annotation resolving to a NAD that
   exists in the same namespace.
2. Every NAD's netAttachDefName equals its own metadata namespace/name.
3. For each network, the CNI "name" field is identical across all its objects.
4. Every allowRule produced both an ingress and an egress object.
5. No script uses ping from a pod as a reachability test. restricted-v2 drops
   NET_RAW, so pod ICMP fails with EPERM regardless of policy — a false
   negative indistinguishable from a policy denial. ICMP is demonstrated from
   VMs only.
6. listenPorts contains at least two ports and the allow rules permit some but
   not all of them, so the demo proves port granularity rather than mere host
   reachability.
7. At least one network has policed: false. Without an unpoliced control
   network the demo cannot prove that policies are scoped per-network, which is
   the finding that actually changes how people design.
8. Committed manifests contain placeholder VLAN IDs and subnets only, with real
   values supplied via values.env and applied by render.sh.
9. For any cudn network: the namespaceSelector label is present on exactly the
   attachedTo namespaces; no raw NAD is emitted for it; every policy-for targets
   <namespace>/<cudn-name>; and the harness asserts the rendered NAD exists
   before applying policy. A cudn network and a nad network never share a vlan id.

VALIDATE — run these and paste the output before declaring done
  # YAML parses, embedded CNI JSON parses, invariants 1-3 hold
  python3 - <<'PY'
  import yaml, json, glob
  for f in sorted(glob.glob('docs/demos/*/manifests/*.yaml')
                + glob.glob('docs/demos/*/policies/*.yaml')):
      for d in [x for x in yaml.safe_load_all(open(f)) if x]:
          k = d.get('kind')
          if k == 'NetworkAttachmentDefinition':
              j = json.loads(d['spec']['config'])
              want = f"{d['metadata']['namespace']}/{d['metadata']['name']}"
              assert j['netAttachDefName'] == want, (f, j['netAttachDefName'], want)
          if k == 'MultiNetworkPolicy':
              a = (d['metadata'].get('annotations') or {})
              assert a.get('k8s.v1.cni.cncf.io/policy-for'), (f, d['metadata']['name'])
          if k == 'ClusterUserDefinedNetwork':
              ln = d['spec']['network']['localnet']
              assert ln['role'] == 'Secondary', (f, 'localnet must be Secondary')
              assert d['spec'].get('namespaceSelector'), (f, 'CUDN needs a namespaceSelector')
  print('invariants 1-3 OK')
  PY

  bash -n docs/demos/*/scripts/*.sh
  kubeconform -ignore-missing-schemas -summary docs/demos/*/manifests/*.yaml
  bash docs/demos/*/scripts/render.sh && \
    python3 -c "import yaml,glob;[list(yaml.safe_load_all(open(f))) for f in glob.glob('docs/demos/*/.rendered/**/*.yaml',recursive=True)];print('rendered YAML valid')"

SANITISATION
Committed artifacts must contain no client identification, no sector framing,
no site or geographic identifiers, no client-specific acronyms, and no real
ASNs, IPs, hostnames, base domains or VLAN IDs. Use neutral placeholders and
the values.env indirection. Treat any acronym you cannot expand as identifying.
gitleaks will not catch a VLAN ID — this is a review-discipline control, so
call it out explicitly in the generated README.

CONSTRAINTS
- Do not generate a NodeNetworkConfigurationPolicy that alters bridge mappings
  unless I ask. If the demo needs one, emit it marked REFERENCE ONLY with a
  warning that applying it changes node networking and is change-controlled.
- Do not modify any generated file to make a validation step pass without first
  telling me what was wrong and getting agreement.
- State applicability in the README: MultiNetworkPolicy is OVN-Kubernetes only.
  It does not exist on Cilium clusters, and neither does UserDefinedNetwork or
  ClusterUserDefinedNetwork. The equivalent on a Cilium cluster is
  CiliumNetworkPolicy, which is identity-based rather than IP-based.
- Note the enforcement point: on ovn-k8s-cni-overlay secondary networks the
  rules become OVN ACLs; on macvlan and SR-IOV NADs the implementation is
  iptables inside the pod netns, which interacts poorly with bridge-bound VM
  interfaces. Keep VM demos on localnet.

REPORT
When done, output: the file tree created, the validation output verbatim, the
test matrix the harness will assert, and any SPEC value you had to interpret
rather than take literally.
```

## Short variant — extend an existing demo

```text
Using the generator rules in docs/demos/multi-network-policy/copilot-instructions.md,
add <network|tenant|allowRule> to docs/demos/<demoName>/. Re-derive every
affected artifact rather than patching one file, re-run the full VALIDATE
block, and show me the output. Preserve all INVARIANTS, especially the
unpoliced control network and the ingress+egress pairing.
```
