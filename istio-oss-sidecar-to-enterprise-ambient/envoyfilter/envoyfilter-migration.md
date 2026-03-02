# Migrating EnvoyFilters from Sidecars to Waypoints

# Objectives
- Understand why sidecar EnvoyFilters cannot be applied directly to waypoints
- Identify the structural changes required for waypoint compatibility
- Migrate a traffic normalization EnvoyFilter to a waypoint
- Replace a sidecar header-injection EnvoyFilter with a native Gateway API HTTPRoute filter
- Understand when to use EnvoyFilters vs native Gateway API resources

## Prerequisites
- This lab assumes you have completed labs `000`–`004` in `/istio-oss-sidecar-to-enterprise-ambient` or `000`-`003` in `/istio-ambient-single-cluster`

Ensure the following environment variables are set:
```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name
```

## Background

In sidecar mode, EnvoyFilters are bound to workloads via `workloadSelector` and target specific traffic contexts (`SIDECAR_INBOUND`, `SIDECAR_OUTBOUND`). Each pod has its own Envoy proxy, so filters apply per-pod.

In ambient mode with waypoints, the model changes fundamentally:

- There is no per-pod Envoy. A waypoint can be scoped to a namespace or to a single Service — the latter provides a similar granularity to sidecar-based filters.
- EnvoyFilters bind to waypoints using `targetRefs` (pointing to a `Gateway` or `Service`) instead of `workloadSelector`.
- The only valid context for waypoint EnvoyFilters is `GATEWAY`. There is no `WAYPOINT` context.
- Several `match.listener.*` fields used in sidecar mode are unsupported against waypoints (port numbers, listener names, SNI, etc.).

> **Solo Enterprise feature:** Waypoint EnvoyFilter support is currently only available in Solo Enterprise Istio builds

### What changes

| Attribute | Sidecar | Waypoint |
|---|---|---|
| Binding | `workloadSelector` | `targetRefs` (Gateway or Service) |
| Context | `SIDECAR_INBOUND` / `SIDECAR_OUTBOUND` | `GATEWAY` |
| `listener.portNumber` | Supported | **Not supported** |
| `listener.name` | Supported | **Not supported** |
| `filterChain.filter` matching | Supported | Supported |
| `HTTP_FILTER` insert | Supported | Supported |
| `NETWORK_FILTER` merge | Supported | Supported |

---

## Example Sidecar EnvoyFilters

This lab works through three example EnvoyFilters from a sidecar-based deployment.

### 1. `traffic-normalization` — Merge slashes in URL paths

This filter merges consecutive slashes in URL paths (e.g., `GET /reviews//0` becomes `GET /reviews/0`). Without it, double-slash paths can bypass route matches or authorization policies that match on exact paths.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: traffic-normalization
  namespace: bookinfo-backends
spec:
  workloadSelector:
    labels:
      app: reviews
  configPatches:
    - applyTo: NETWORK_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
      patch:
        operation: MERGE
        value:
          typed_config:
            '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
            merge_slashes: true
```

### 2. `header-injection` — Add a version response header

This filter uses a Lua script to append `X-Service-Version: v1.21.0` to every response. It targets inbound sidecar traffic.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: header-injection
  namespace: bookinfo-backends
spec:
  workloadSelector:
    labels:
      app: reviews
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: SIDECAR_INBOUND
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
              subFilter:
                name: envoy.filters.http.router
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.lua
          typed_config:
            '@type': type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
            inlineCode: |
              function envoy_on_response(response_handle)
                response_handle:headers():add("X-Service-Version", "v1.21.0")
              end
```

### 3. `grpc-envoyfilter` — gRPC JSON transcoding (reference only)

This filter inserts a gRPC JSON transcoder to allow REST clients to call a gRPC backend. The proto descriptor is embedded as a binary blob in `proto_descriptor_bin`.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: grpc-json-transcoder
  namespace: bookinfo-backends
spec:
  workloadSelector:
    labels:
      app: bigquery-ingest
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: SIDECAR_INBOUND
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
              subFilter:
                name: envoy.filters.http.router
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.grpc_json_transcoder
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.grpc_json_transcoder.v3.GrpcJsonTranscoder
            services:
              - "iasi.ame.bigqueryIngestionService.v1.BigQueryIngestionServiceApi"
            proto_descriptor_bin: "CgwFChVnb29nbGVuYXBpL2hodHAtdHJhbnNjb2Rlci5wcm90bxICGg=="
```

---

## Setup

Deploy a waypoint proxy for the `bookinfo-backends` namespace and label the namespace to route all inbound service traffic through it:
```bash
kubectl apply --context $KUBECONTEXT_CLUSTER1 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: bookinfo-backends
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
    allowedRoutes:
      namespaces:
        from: All
EOF

kubectl rollout status deployment/waypoint -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1
kubectl label namespace bookinfo-backends istio.io/use-waypoint=waypoint --context $KUBECONTEXT_CLUSTER1
```

---

## Example 1 — Migrate `traffic-normalization` to a Waypoint

The `traffic-normalization` filter is the simplest example to migrate because `context: GATEWAY` is already correct, so only the manifest wrapper and `targetRefs` need to be added:


```bash
kubectl apply --context $KUBECONTEXT_CLUSTER1 -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: traffic-normalization
  namespace: bookinfo-backends
spec:
  targetRefs:
  - name: waypoint
    kind: Gateway
    group: gateway.networking.k8s.io
  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: MERGE
      value:
        typed_config:
          '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          merge_slashes: true
EOF
```

### What changed from the sidecar version

| Field | Before | After |
|---|---|---|
| `workloadSelector` | `app: reviews` | Replaced by `targetRefs` |
| `context` | `GATEWAY` | `GATEWAY` (unchanged) |

> **Note:** `targetRefs` pointing to the `Gateway` applies the filter to all services managed by the waypoint — appropriate here since URL normalization should apply broadly. Example 3 shows how to scope a filter to a single service within the same waypoint.

### Verify

Send a request with a double slash in the path and confirm it succeeds (200 rather than 404):
```bash
kubectl exec deploy/productpage-v1 -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1 -- \
  python3 -c "
import urllib.request, urllib.error
try:
    code = urllib.request.urlopen('http://reviews.bookinfo-backends:9080/reviews//0').getcode()
    print(f'Status: {code}')
except urllib.error.HTTPError as e:
    print(f'Status: {e.code}')"
```

Without `merge_slashes`, the double-slash path would not match the reviews route and return 404. With the filter applied, the waypoint normalizes it before routing and the request succeeds.

---

## Example 2 — Replace `header-injection` with a Native Gateway API Filter

The `header-injection` EnvoyFilter uses Lua to append `X-Service-Version: v1.21.0` to responses. Adding a response header is a first-class capability in the Kubernetes Gateway API — no EnvoyFilter required.

> **Solo Enterprise guidance:** Prefer native Gateway API resources over EnvoyFilters wherever possible. EnvoyFilters tie you to internal Envoy XDS structure, which can change across releases. Gateway API `HTTPRoute` filters are standardized, version-stable, and simpler to maintain.

Apply an `HTTPRoute` with a `ResponseHeaderModifier` filter scoped to the `reviews` Service:

```bash
kubectl apply --context $KUBECONTEXT_CLUSTER1 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-version-header
  namespace: bookinfo-backends
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: reviews
    port: 9080
  rules:
  - filters:
    - type: ResponseHeaderModifier
      responseHeaderModifier:
        add:
        - name: X-Service-Version
          value: "v1.21.0"
    backendRefs:
    - name: reviews
      port: 9080
EOF
```

The waypoint processes the `HTTPRoute` and adds the header to every response from `reviews` before it reaches the caller — no Lua, no Envoy-specific config.

| | Sidecar EnvoyFilter (Lua) | HTTPRoute `ResponseHeaderModifier` |
|---|---|---|
| API stability | Tied to internal Envoy XDS | Kubernetes Gateway API standard |
| Upgrade risk | May break when Envoy XDS changes | Stable across Istio versions |
| Portability | Istio-specific | Works with any Gateway API implementation |
| Complexity | Lua script + filter chain matching | Declarative, 5 lines |

### Verify

```bash
kubectl exec deploy/productpage-v1 -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1 -- \
  python3 -c "
import urllib.request
resp = urllib.request.urlopen('http://reviews.bookinfo-backends:9080/reviews/0')
print('X-Service-Version:', resp.headers.get('X-Service-Version', 'not found'))"
```

You should see:
```
X-Service-Version: v1.21.0
```

The waypoint adds the header to every response from `reviews` before it reaches the caller.

---

## Example 3 — Converting `grpc-envoyfilter` to a Waypoint

Example 1 used `targetRefs` pointing to the `Gateway`, applying the filter to all services managed by the waypoint. This example shows how to scope an EnvoyFilter to a single service within that same waypoint — the transcoder only knows how to handle traffic for the declared proto services, so applying it across all services would break non-gRPC backends.

The `grpc-envoyfilter` snippet above inserts `envoy.filters.http.grpc_json_transcoder` into the HTTP filter chain, allowing REST clients to call a gRPC backend. The proto descriptor is embedded as a binary blob in `proto_descriptor_bin`. Below is the complete waypoint-compatible EnvoyFilter:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: grpc-json-transcoder
  namespace: <service-namespace>
spec:
  targetRefs:
  - name: <grpc-service-name>
    kind: Service
    group: ""
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
            subFilter:
              name: envoy.filters.http.router
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.grpc_json_transcoder
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.grpc_json_transcoder.v3.GrpcJsonTranscoder
          services:
            - "iasi.ame.bigqueryIngestionService.v1.BigQueryIngestionServiceApi"
          proto_descriptor_bin: "CgwFChVnb29nbGVuYXBpL2hodHAtdHJhbnNjb2Rlci5wcm90bxICGg=="
```

### What was added

| Field | Before | After |
|---|---|---|
| `workloadSelector` | `app: bigquery-ingest` | Replaced by `targetRefs` scoped to the gRPC `Service` |
| `context` | `SIDECAR_INBOUND` | `GATEWAY` |

---

## Cleanup

Remove the EnvoyFilter and HTTPRoute applied in this lab:
```bash
kubectl delete envoyfilter traffic-normalization -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
kubectl delete httproute reviews-version-header -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
```

To remove the waypoint:
```bash
kubectl label namespace bookinfo-backends istio.io/use-waypoint- --context $KUBECONTEXT_CLUSTER1
kubectl delete gateway waypoint -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
```

## Summary

| Filter | Migration approach | Key change |
|---|---|---|
| `traffic-normalization` | EnvoyFilter → waypoint EnvoyFilter | Replace `workloadSelector` with `targetRefs` (Gateway); `context: GATEWAY` was already correct |
| `header-injection` | EnvoyFilter → native `HTTPRoute` `ResponseHeaderModifier` | No EnvoyFilter needed; Gateway API has a first-class filter for response headers |
| `grpc-envoyfilter` | EnvoyFilter → waypoint EnvoyFilter | Replace `workloadSelector` with `targetRefs` (Service); change `context` from `SIDECAR_INBOUND` to `GATEWAY`; scope to the specific gRPC Service to avoid breaking non-gRPC backends |

The core migration checklist for any sidecar EnvoyFilter moving to a waypoint:
1. Ask: is there a native Gateway API equivalent? If yes, prefer it over the EnvoyFilter.
2. Replace `workloadSelector` with `targetRefs` — use `Gateway` to apply to all services in the waypoint, or `Service` to scope to a single service.
3. Change `context` to `GATEWAY`
4. Remove any unsupported match fields (`listener.portNumber`, `listener.name`, `filterChain.name`, etc.)
