# Cilium learning cluster (kind) — engineer guide

A self-contained walkthrough for bringing up the local Cilium 1.19
laboratory, working through the L3/L4/L7 `CiliumNetworkPolicy`
ladder, and understanding the most common policy gotcha — all
without touching a cloud cluster.

This document is the engineer-facing companion to
[ADR 0008 — Cilium scope split](adr/0008-cilium-scope-split.md) and
[ADR 0009 — kind Cilium learning cluster](adr/0009-kind-cilium-learning-cluster.md).
If you only have time to read one thing, read this; if you want the
"why" behind each choice, read the ADRs.

## TL;DR

```bash
task kind:up:cilium     # ~3–5 min: kind + Cilium 1.19 + Hubble
task kind:cilium-status # confirm Cilium agents healthy
task kind:hubble-ui     # port-forward Hubble UI to localhost:12000
# ... do learning ...
task kind:down          # destroys the cluster + all port-forwards
```

Open <http://localhost:12000> for Hubble. Everything else lives in
this guide.

> **Recorded run.** All captured output in this document was taken
> from a real run on 2026-05-24 on macOS Darwin 25.5.0 (arm64),
> Docker 20.10.22, kind v0.30.0, Cilium 1.19.4, Kubernetes 1.34.0,
> podinfo 6.12.0. Reproduce by running the commands as written; you
> should see the same shape of output with later patch versions.

## 1. Why kind and not the cloud cluster

The production target is OpenShift Virtualization on bare metal with
Cilium 1.19 as the CNI. Our lab budget supports Azure Red Hat
OpenShift, but **ARO is a managed service** — Microsoft and Red Hat
operate the CNI (OVN-Kubernetes), and there is no
`install-config.yaml` step or operator-side toggle that swaps it for
Cilium. Cilium therefore cannot run live on the lab's ARO cluster.

The scope split (ADR 0008) is:

- **Live Cilium runs on local kind** — Helm install, fast iteration,
  this guide.
- **Bare-metal Cilium manifests** live read-only under
  `clusters/baremetal-reference/manifests/` for schema validation
  and PR review, never applied.
- **ARO clusters keep OVN-Kubernetes** — NetworkPolicy on ARO uses
  standard `networking.k8s.io/v1`, never `CiliumNetworkPolicy`.

Anything you learn here transfers directly to the bare-metal reference
artefacts because they use the same `CiliumNetworkPolicy` /
`CiliumClusterwideNetworkPolicy` API.

## 2. What the cluster looks like

| Component        | Choice                                      | Rationale                                                                              |
|------------------|---------------------------------------------|----------------------------------------------------------------------------------------|
| Node count       | 3 (1 control-plane + 2 workers)             | Two workers means pod-to-pod traffic crosses a node boundary — visible in Hubble       |
| Default CNI      | Disabled (`disableDefaultCNI: true`)        | kindnet would otherwise claim the CNI seat before Cilium installs                      |
| kube-proxy       | **Left in place**                           | KPR is a Phase-2 learning topic in its own right; the default install demonstrates the "with kube-proxy" baseline |
| Datapath         | VXLAN tunnel (Cilium default)               | Native routing needs an underlay we don't have on a laptop                             |
| Cilium version   | `1.19.4` (pinned in `scripts/tasks/kind.yml`) | Tracks the bare-metal reference manifests                                              |
| IPAM             | `kubernetes` (kind allocates per-node CIDRs)  | The right fit for kind; cluster-pool would conflict                                    |
| Hubble           | Enabled (agent + relay + UI)                | This is the whole reason to use Cilium — observability is non-optional                 |
| Encryption / BGP / KPR | **Not enabled by default**             | Each is its own learning step; turning them on by default would hide the toggle the exercises are meant to flip |

Cluster name: `sigma-kv` (defined as `KIND_CLUSTER` in
`scripts/tasks/kind.yml`). Pod CIDR `10.244.0.0/16`, service CIDR
`10.96.0.0/16`, Docker bridge `172.18.0.0/16` — all stock kind
defaults. Node names: `sigma-kv-control-plane`,
`sigma-kv-worker`, `sigma-kv-worker2`.

## 3. Prerequisites

| Tool              | Version we test against | Install                          |
|-------------------|-------------------------|----------------------------------|
| Docker Desktop    | 20.10+                  | <https://www.docker.com/products/docker-desktop> |
| `kind`            | 0.30+                   | `brew install kind`              |
| `helm`            | 3.12+                   | `brew install helm`              |
| `kubectl`         | 1.30+                   | `brew install kubectl`           |
| `task` (go-task)  | 3.x                     | `brew install go-task/tap/go-task` |

`task bootstrap` from the repo root will verify the lot.

Docker Desktop must be running before `task kind:up:cilium` — kind
creates the cluster as a Docker container, so without the daemon it
fails immediately.

## 4. Bringing it up

Two entrypoints live in `scripts/tasks/kind.yml`:

| Task                       | Installs                                | Use for                                       |
|----------------------------|-----------------------------------------|-----------------------------------------------|
| `task kind:up:cilium`      | kind + Cilium + Hubble                  | Cilium learning loop (this guide) — **default** |
| `task kind:up:full`        | also adds KubeVirt + CDI + Forklift     | Phase-4 KubeVirt / MTV work — slower            |

For everything in this guide, use `kind:up:cilium`.

Helper tasks:

| Task                       | What it does                                                          |
|----------------------------|-----------------------------------------------------------------------|
| `task kind:cilium-status`  | `cilium-dbg status` against the running daemonset                     |
| `task kind:hubble-ui`      | Port-forward `svc/hubble-ui` to <http://localhost:12000>              |
| `task kind:install-cilium` | Re-run the Helm install (idempotent — use after editing chart values) |
| `task kind:down`           | Destroy the cluster                                                   |

### Bring-up log (recorded run)

Excerpt from `task kind:up:cilium` on a fresh cluster. The notable
milestones, in order:

```text
task: [kind:up:cilium] kind create cluster --name sigma-kv --config clusters/kind-local/kind-config.yaml
Creating cluster "sigma-kv" ...
 ✓ Ensuring node image (kindest/node:v1.34.0)
 ✓ Preparing nodes
 ✓ Writing configuration
 ✓ Starting control-plane
 ✓ Installing StorageClass
Set kubectl context to "kind-sigma-kv"

task: [kind:install-cilium] helm repo add cilium https://helm.cilium.io/
task: [kind:install-cilium] helm repo update
task: [kind:install-cilium] helm upgrade --install cilium cilium/cilium \
    --version 1.19.4 --namespace kube-system \
    --set image.pullPolicy=IfNotPresent --set ipam.mode=kubernetes \
    --set hubble.enabled=true --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true
Release "cilium" does not exist. Installing it now.

task: [kind:install-cilium] kubectl -n kube-system rollout status ds/cilium --timeout=300s
daemon set "cilium" successfully rolled out
```

Note **no `Installing CNI` step** — `disableDefaultCNI: true` is
doing its job, the CNI seat is reserved for Cilium. End-to-end took
~5 minutes on a warm Docker image cache. The slowest leg is the
DaemonSet rollout (6 init containers per node).

### What "Ready" looks like

After `task kind:up:cilium` finishes, captured from the recorded run:

```text
$ kubectl get nodes
NAME                     STATUS   ROLES           AGE   VERSION
sigma-kv-control-plane   Ready    control-plane   27m   v1.34.0
sigma-kv-worker          Ready    <none>          27m   v1.34.0
sigma-kv-worker2         Ready    <none>          27m   v1.34.0

$ kubectl -n kube-system get pods -l 'k8s-app in (cilium,hubble-relay,hubble-ui)'
NAME                            READY   STATUS    RESTARTS   AGE
cilium-bqzlz                    1/1     Running   0          27m
cilium-sp4w8                    1/1     Running   0          27m
cilium-xr9ns                    1/1     Running   0          27m
hubble-relay-7bf487775d-6pbtm   1/1     Running   0          27m
hubble-ui-6bb97d8894-s9rx2      2/2     Running   0          27m

$ task kind:cilium-status
task: [kind:cilium-status] kubectl -n kube-system exec ds/cilium -- cilium-dbg status
KVStore:                 Disabled
Kubernetes:              Ok         1.34 (v1.34.0) [linux/arm64]
Kubernetes APIs:         ["cilium/v2::CiliumCIDRGroup", "cilium/v2::CiliumClusterwideNetworkPolicy",
                          "cilium/v2::CiliumEndpoint", "cilium/v2::CiliumNetworkPolicy",
                          "cilium/v2::CiliumNode", "core/v1::Pods",
                          "networking.k8s.io/v1::NetworkPolicy"]
KubeProxyReplacement:    False
Host firewall:           Disabled
SRv6:                    Disabled
CNI Chaining:            none
CNI Config file:         successfully wrote CNI configuration file to /host/etc/cni/net.d/05-cilium.conflist
Cilium:                  Ok   1.19.4 (v1.19.4-95e477fd)
NodeMonitor:             Listening for events on 2 CPUs with 64x4096 of shared memory
Cilium health daemon:    Ok
IPAM:                    IPv4: 8/254 allocated from 10.244.3.0/24,
Routing:                 Network: Tunnel [vxlan]   Host: Legacy
Attach Mode:             Legacy TC
Device Mode:             veth
Masquerading:            IPTables [IPv4: Enabled, IPv6: Disabled]
Controller Status:       44/44 healthy
Proxy Status:            OK, ip 10.244.3.153, 0 redirects active on ports 10000-20000, Envoy: external
Hubble:                  Ok   Current/Max Flows: 4095/4095 (100.00%), Flows/s: 7.40   Metrics: Disabled
Encryption:              Disabled
Cluster health:          3/3 reachable
Modules Health:          Stopped(24) Degraded(0) OK(87)
```

The lines worth reading carefully:

- `Cilium: Ok 1.19.4` — agent is healthy.
- `Cluster health: 3/3 reachable` — all three nodes' cilium-health
  endpoints can reach each other. On a fresh install this can show
  `0/3` for the first ~2 min while the probe interval ticks; that's
  not a real failure.
- `Hubble: Ok ... Flows/s: 7.40` — observability pipeline is
  capturing live traffic, even though the only thing on the cluster
  is system pods.
- `KubeProxyReplacement: False` — deliberate (see Section 2).
- `Encryption: Disabled` — deliberate.
- `Modules Health: Stopped(24) Degraded(0) OK(87)` — `Stopped`
  counts features that aren't enabled (KPR, SRv6, …); only
  `Degraded` would be a problem.

Until Cilium finishes installing, nodes show `NotReady` and pods
stay `ContainerCreating` because they have no pod IP yet. This is
expected on the first 1–2 minutes after `kind create cluster`.

## 5. Walkthrough — L3 / L4 / L7 with the star-wars demo

The Cilium upstream demo is two ships and a Death Star. Empire
ships (`org=empire`) should be able to land on the Death Star;
Alliance ships (`org=alliance`) should not. The interesting bit is
seeing **how** they're refused — silent drop vs. HTTP 403 — and what
that tells you about where the policy is enforced in the stack.

### 5a. Deploy the demo

```bash
kubectl create namespace starwars
kubectl -n starwars apply -f \
  https://raw.githubusercontent.com/cilium/cilium/v1.19.4/examples/minikube/http-sw-app.yaml
kubectl -n starwars wait --for=condition=Ready pod --all --timeout=120s
```

You now have:

- `deathstar` Service + 2-replica Deployment (`class=deathstar, org=empire`)
- `tiefighter` standalone Pod (`class=tiefighter, org=empire`)
- `xwing` standalone Pod (`class=xwing, org=alliance`)

### 5b. Baseline — no policy, anyone can land

Captured from the recorded run:

```text
$ kubectl -n starwars exec tiefighter -- \
    curl -sS --max-time 5 -XPOST deathstar.starwars.svc.cluster.local/v1/request-landing
Ship landed

$ kubectl -n starwars exec xwing -- \
    curl -sS --max-time 5 -XPOST deathstar.starwars.svc.cluster.local/v1/request-landing
Ship landed
```

Open <http://localhost:12000>, switch the namespace dropdown to
`starwars` — both flows are green / `forwarded`.

### 5c. Apply the L3/L4 policy — Empire only

```bash
kubectl -n starwars apply -f \
  https://raw.githubusercontent.com/cilium/cilium/v1.19.4/examples/minikube/sw_l3_l4_policy.yaml
```

The policy (`rule1`) restricts ingress to deathstar so only pods
labelled `org=empire` can reach it on TCP/80.

Captured from the recorded run:

```text
$ kubectl -n starwars get cnp
NAME    AGE   VALID
rule1   0s    True

$ kubectl -n starwars exec tiefighter -- \
    curl -sS --max-time 5 -XPOST deathstar.starwars.svc.cluster.local/v1/request-landing
Ship landed

$ time kubectl -n starwars exec xwing -- \
    curl -sS --max-time 5 -XPOST deathstar.starwars.svc.cluster.local/v1/request-landing
curl: (28) Connection timed out after 5000 milliseconds
command terminated with exit code 28
kubectl ... 0.06s user 0.02s system 1% cpu 5.119 total
```

In Hubble: xwing → deathstar flows are now red / `policy-denied`.
Crucially, **the flow rows show no HTTP verb or path** — the packet
was dropped at L3/L4 before Cilium's Envoy proxy ever saw the
request. The `Exit code 28` is curl's "timeout" — the expected
outcome of the policy demo, not an error.

### 5d. Layer in L7 — Empire can land but not "exhaust port"

```bash
kubectl -n starwars apply -f \
  https://raw.githubusercontent.com/cilium/cilium/v1.19.4/examples/minikube/sw_l3_l4_l7_policy.yaml
```

Same selectors plus an HTTP rule: only `POST /v1/request-landing` is
allowed for empire ships. Anything else gets rejected at L7.

Captured from the recorded run:

```text
$ kubectl -n starwars get cnp
NAME    AGE   VALID
rule1   52s   True

$ kubectl -n starwars exec tiefighter -- \
    curl -sS --max-time 5 -XPOST deathstar.starwars.svc.cluster.local/v1/request-landing
Ship landed

$ kubectl -n starwars exec tiefighter -- \
    curl -sS --max-time 5 -XPUT  deathstar.starwars.svc.cluster.local/v1/exhaust-port
Access denied

$ time kubectl -n starwars exec xwing -- \
    curl -sS --max-time 5 -XPOST deathstar.starwars.svc.cluster.local/v1/request-landing
curl: (28) Connection timed out after 5000 milliseconds
command terminated with exit code 28
kubectl ... 0.05s user 0.02s system 1% cpu 5.098 total
```

Three different outcomes, three different enforcement points:

| Caller     | Method/Path                  | Result                          | Enforcement                                                |
|------------|------------------------------|---------------------------------|------------------------------------------------------------|
| tiefighter | `POST /v1/request-landing`   | `Ship landed`                   | L3/L4 ✓ + L7 ✓                                             |
| tiefighter | `PUT /v1/exhaust-port`       | `Access denied` (fast response) | L3/L4 ✓, **L7 rejected by Envoy** (packet reached the proxy, was parsed, refused) |
| xwing      | `POST /v1/request-landing`   | curl timeout after 5s           | **L3/L4 drop** (packet never reached the proxy)            |

The fact that tiefighter's denial returns **instantly with a string**
while xwing's denial returns **after a timeout with nothing** is the
observable signature of L7-vs-L4 enforcement.

In Hubble: notice the tiefighter rows now show HTTP verbs and paths
(Envoy is on-path, parsing). The denied PUT shows `http-403`
distinct from xwing's `policy-denied`. **That visible difference is
the signature of L7 vs L4 enforcement.**

### 5e. Cleanup

```bash
kubectl delete namespace starwars      # nuke everything including policies
# or, to keep the namespace and just drop policies:
kubectl -n starwars delete cnp --all
```

## 6. Visual testing — podinfo

`podinfo` is a small Go web app that exposes a dashboard, JSON
endpoints, and a load-balancer-friendly hostname field. Useful for
poking at policies against a real-looking application instead of a
toy.

```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update podinfo
kubectl create namespace podinfo
helm upgrade --install podinfo podinfo/podinfo \
  --namespace podinfo --set replicaCount=2 --wait
kubectl -n podinfo port-forward svc/podinfo 8080:9898
```

Captured from the recorded run:

```text
$ kubectl -n podinfo get pods,svc
NAME                           READY   STATUS    RESTARTS   AGE
pod/podinfo-544999cb75-m44qv   1/1     Running   0          13m
pod/podinfo-544999cb75-xcvwc   1/1     Running   0          13m

NAME              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)             AGE
service/podinfo   ClusterIP   10.96.40.169   <none>        9898/TCP,9999/TCP   13m

$ curl -sS --max-time 3 http://localhost:8080/api/info
{
  "hostname": "podinfo-544999cb75-xcvwc",
  "version": "6.12.0",
  "revision": "a547e00b6cd16bf4017852205169f29f74a86452",
  "color": "#34577c",
  "message": "greetings from podinfo v6.12.0",
  "goos": "linux",
  "goarch": "arm64",
  "runtime": "go1.26.3",
  ...
}
```

Two replicas were placed on different workers, so refreshing the
browser tab rotates the `hostname` field — visible service-level
load balancing without any extra config.

| URL                                         | What it serves                                                      |
|---------------------------------------------|---------------------------------------------------------------------|
| <http://localhost:8080>                     | Dashboard. The `hostname` field rotates between replicas on refresh — visible L4 load balancing |
| <http://localhost:8080/api/info>            | JSON status (good for `curl` / scripted tests)                       |
| <http://localhost:8080/healthz>             | Liveness probe                                                      |
| <http://localhost:8080/readyz>              | Readiness probe                                                     |
| <http://localhost:12000/?namespace=podinfo> | Hubble UI scoped to the podinfo namespace                            |

Teardown: `kubectl delete namespace podinfo`.

## 7. The gotcha — host bypass on `ingressDeny: fromEntities:[all]`

Try this against podinfo (assumes podinfo is running):

```yaml
# kubectl -n podinfo apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: podinfo-deny-all-ingress
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: podinfo
  ingressDeny:
    - fromEntities:
        - all
```

Captured from the recorded run:

```text
$ kubectl -n podinfo get cnp
NAME                       AGE   VALID
podinfo-deny-all-ingress   35s   True

$ curl -sS --max-time 3 http://localhost:8080/api/info
{
  "hostname": "podinfo-544999cb75-xcvwc",
  "version": "6.12.0",
  ...
}
```

That still works. The policy is `VALID: True` and active. **Why
doesn't it block?**

> **First attempt to apply this policy used `ingress: []`** — Cilium
> 1.19 rejects that with `rule must have at least one of Ingress,
> IngressDeny, Egress, EgressDeny`. The validation failure shows in
> `kubectl get cnp` as `VALID: False`, and `-o yaml` surfaces the
> reason in `status.conditions[].message`. The canonical "deny all"
> shape in 1.19 is `ingressDeny: [{ fromEntities: [all] }]`, as
> above.

### Why

`kubectl port-forward` tunnels traffic through the kube-apiserver
into the pod's network namespace. From the pod's perspective the
source of that traffic is the **local node's host network
namespace**, not another pod. In Cilium's identity model, that
traffic carries the `host` reserved identity — and Cilium has a
built-in "always allow host → local pod" rule that survives even
`ingressDeny: fromEntities:[all]`.

This is intentional. Without it, kubelet's liveness and readiness
probes (also originating from the host network namespace) would be
dropped and every pod under a deny policy would be killed.

### How to actually test the policy

From inside the cluster. Captured from the recorded run, with the
deny CNP still in place:

```text
$ kubectl -n starwars exec xwing -- \
    curl -sS --max-time 5 http://podinfo.podinfo.svc.cluster.local:9898/api/info
curl: (28) Connection timed out after 5000 milliseconds
command terminated with exit code 28

$ curl -sS --max-time 3 http://localhost:8080/api/info
{ "hostname": "podinfo-544999cb75-xcvwc", "version": "6.12.0", ... }
```

Same destination, same policy, two different sources — one denied,
one allowed. In Hubble both flows show up side by side:
`xwing → podinfo` is `policy-denied` (red), `host → podinfo`
(port-forward) is `forwarded` (green). That side-by-side view is
the cleanest way to internalise the host-bypass behaviour.

Cleanup once you've understood the effect:

```bash
kubectl -n podinfo delete cnp podinfo-deny-all-ingress
```

Verify pod-to-pod traffic returns:

```text
$ kubectl -n starwars exec xwing -- \
    curl -sS --max-time 5 http://podinfo.podinfo.svc.cluster.local:9898/api/info
{ "hostname": "podinfo-544999cb75-xcvwc", "version": "6.12.0", ... }
```

### Operational implications

| Lesson                                                                                       |
|----------------------------------------------------------------------------------------------|
| **Never use `kubectl port-forward` as a reachability test for a deny policy.** It bypasses pod policy by design. |
| **Validate from in-cluster pods.** Keep a debug pod handy (anything with `curl`, `wget`, or `nc`). |
| **The cluster-wide override is `policy-allow-host-to-pod=false` in CiliumConfig.** Don't flip it on a real cluster without a very good reason — you'll break kubelet probes. |
| **Production deny baselines belong in a `CiliumClusterwideNetworkPolicy`, not a per-namespace CNP**, and need to think explicitly about host traffic. The bare-metal reference manifests under `clusters/baremetal-reference/` will need this. |

## 8. Tearing down

| What                                | Command                                       |
|-------------------------------------|-----------------------------------------------|
| Just policies                       | `kubectl delete cnp -A --all`                 |
| Star-wars demo                      | `kubectl delete namespace starwars`           |
| podinfo                             | `kubectl delete namespace podinfo`            |
| Hubble port-forward                 | `kill` the `kubectl port-forward` process     |
| **Everything (cluster + processes)** | `task kind:down`                              |

`task kind:down` is destructive but cheap — re-running
`task kind:up:cilium` rebuilds the lab from scratch in 3–5 minutes
on a warm Docker image cache.

## 9. Where this fits in the bigger picture

- **Phase 2 of [`docs/learning-roadmap.md`](learning-roadmap.md)** —
  this cluster is the GitOps + Cilium bootstrap target. ArgoCD on
  the ARO hub will eventually drive its content via the kind spoke,
  but for now the cluster is happiest as a standalone Cilium lab.
- **`clusters/baremetal-reference/manifests/`** — the bare-metal
  Cilium-on-OpenShift install path that this kind cluster
  approximates. Same `CiliumNetworkPolicy` API; different install
  path (OLM operator instead of Helm).
- **`.claude/skills/cilium-openshift/SKILL.md`** — the authoritative
  cross-reference for Cilium 1.19 specifics on the bare-metal
  target. The Helm install for kind matches its recommended
  baseline for non-OpenShift clusters.

## 10. Next steps in the learning ladder

The default install deliberately leaves these *off* so each is its
own discoverable change rather than something pre-baked:

| Topic                       | What to read first                                                              |
|-----------------------------|---------------------------------------------------------------------------------|
| kube-proxy replacement (KPR) | <https://docs.cilium.io/en/v1.19/network/kubernetes/kubeproxy-free/>             |
| WireGuard transparent encryption | <https://docs.cilium.io/en/v1.19/security/network-encryption/>             |
| Hubble metrics + Prometheus | <https://docs.cilium.io/en/v1.19/observability/metrics/>                         |
| Cilium connectivity test    | `kubectl -n kube-system exec ds/cilium -- cilium-dbg connectivity test`         |
| BGP control plane (lab only — out of scope per ADR 0008) | <https://docs.cilium.io/en/v1.19/network/bgp-control-plane/> |

Each of the first three is enabled by editing the Helm values in
`scripts/tasks/kind.yml` and re-running `task kind:install-cilium`
(the chart install is idempotent). Try one at a time; resist the
urge to enable them all together — you lose the ability to attribute
behaviour change to a specific knob.

## References

- [ADR 0008 — Cilium scope split](adr/0008-cilium-scope-split.md)
- [ADR 0009 — kind Cilium learning cluster](adr/0009-kind-cilium-learning-cluster.md)
- [Learning roadmap](learning-roadmap.md) — Phase 2
- `.claude/skills/cilium-openshift/SKILL.md` — Cilium 1.19 cross-reference
- [Cilium 1.19 kind install guide](https://docs.cilium.io/en/v1.19/installation/kind/)
- [Cilium 1.19 Helm reference](https://docs.cilium.io/en/v1.19/helm-reference/)
- [Cilium policy language reference](https://docs.cilium.io/en/v1.19/security/policy/language/)
