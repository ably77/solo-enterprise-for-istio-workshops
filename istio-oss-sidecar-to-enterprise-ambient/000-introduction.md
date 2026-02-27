# OSS Istio Sidecar to Solo Enterprise Ambient — Introduction

## Migration Narrative

Many organizations run open-source Istio in sidecar mode today. Sidecars work — but they come with real operational costs: every pod carries an Envoy proxy, rollouts require restarts to inject or upgrade proxies, and resource overhead scales linearly with workload count.

**Solo Enterprise Istio Ambient** eliminates the sidecar entirely. ztunnel runs as a DaemonSet on each node, transparently securing all pod-to-pod traffic with mTLS without any changes to application manifests. Waypoints provide opt-in L7 capability for the services that need it.

This workshop walks through an **in-place upgrade** — the realistic production path — starting from a running OSS Istio cluster with sidecar-injected workloads.

## Three-Phase Journey

### Phase 1 — Start with OSS Istio (Labs 001–003)
Install community Istio using the official Helm charts, deploy the Bookinfo sample application with sidecar injection enabled, and expose it via a Gateway API ingress. This is the "before" state — pods show `2/2 READY` (app container + Envoy sidecar).

### Phase 2 — Migrate to Solo Ambient (Labs 004–005)
Perform an in-place upgrade from OSS Istio to Solo Enterprise Istio Ambient. This replaces the sidecar-based control plane with the ambient data plane (ztunnel + CNI). Crucially, **existing sidecar workloads keep running during the upgrade** — there is a coexistence period where both models operate simultaneously. Then migrate namespaces one-by-one: remove the sidecar injection label, add the ambient label, restart pods. Pods now show `1/1 READY`.

### Phase 3 — Zero-Trust & L7 (Labs 006–007)
Now that workloads are in ambient mode, apply Istio AuthorizationPolicy to establish zero-trust access control. Then deploy a waypoint proxy to unlock L7 capabilities: HTTP method authorization, weighted traffic splitting, fault injection, and retries.

## Objectives

- Install OSS Istio (sidecar mode) using community Helm charts
- Deploy Bookinfo with sidecar injection and validate `2/2` pod readiness
- Expose Bookinfo via Gateway API HTTPRoute
- Upgrade in-place from OSS Istio to Solo Enterprise Istio Ambient
- Migrate bookinfo namespaces from sidecar → ambient (validate `1/1` and HBONE)
- Apply zero-trust AuthorizationPolicy using ztunnel-enforced L4 policies
- Deploy a waypoint and configure L7 traffic management

## Validated on

- Kubernetes ≥ 1.29
- OSS Istio 1.26.8 (start)
- Solo Istio 1.29.0-solo (target)
- Gloo Platform 2.12.0

## License Key Details
Gloo Trial License Expires:
```
```
