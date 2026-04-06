# Distributed Tracing

# Objectives
- Deploy Jaeger as a distributed tracing backend
- Configure Istio to export traces to Jaeger via OpenTelemetry
- Enable request tracing at the ingress gateway using the Telemetry API
- Configure ztunnel L7 distributed tracing (Solo-specific feature)
- Enable tracing at waypoints to capture L7 policy enforcement spans
- Observe end-to-end trace spans across the ingress gateway, waypoints, and ztunnel

## Prerequisites
- This lab assumes you have completed labs `001-004`

## Background

In community Istio ambient mode, ztunnel operates at L4 and does not emit distributed trace spans. With the Solo distribution of Istio, ztunnel is enhanced with L7 observability and can report HTTP-level trace spans to a tracing backend.

There are three distinct trace sources in this lab:

| Source | Mechanism | What it captures |
|---|---|---|
| **Ingress gateway** | Envoy proxy; configured via Telemetry API | Initiates the trace; records gateway → service latency |
| **Waypoints** | Envoy proxy; configured via Telemetry API | Attaches as `CHILD_OF`; records L7 policy enforcement at each service boundary |
| **ztunnel** | Solo L7 extension; configured via Helm | Attaches as `FOLLOWS_FROM`; records individual transport tunnel segments |

> **Important:** ztunnel cannot initiate a new trace span. It can only add spans to a trace that was already started by an Envoy proxy (ingress gateway or waypoint). This means the ingress gateway must have tracing enabled for ztunnel spans to appear alongside it.

## Set environment variables

```bash
export KUBECONTEXT_CLUSTER1=cluster1   # Replace with your actual kubectl context
export ISTIO_VERSION=1.29.0
```

## Step 1: Deploy Jaeger

Jaeger is an open-source distributed tracing platform. Istio provides a sample addon deployment suitable for demos and workshops.

```bash
ISTIO_MINOR=$(echo $ISTIO_VERSION | cut -d. -f1,2)

kubectl apply --context $KUBECONTEXT_CLUSTER1 \
  -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_MINOR}/samples/addons/jaeger.yaml
```

Wait for Jaeger to be ready:

```bash
kubectl rollout status deploy/jaeger -n istio-system \
  --watch --timeout=90s --context $KUBECONTEXT_CLUSTER1
```

Verify the Jaeger pods and services are running:

```bash
kubectl get pods,svc -n istio-system -l app=jaeger --context $KUBECONTEXT_CLUSTER1
```

Expected output:

```
NAME                          READY   STATUS    RESTARTS   AGE
pod/jaeger-7f8c6d848b-l9s7q   1/1     Running   0          30s

NAME                        TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)
service/jaeger-collector    ClusterIP   10.96.12.34   <none>        14268/TCP,4317/TCP,4318/TCP
service/tracing             ClusterIP   10.96.56.78   <none>        80/TCP,16685/TCP
service/zipkin              ClusterIP   10.96.90.12   <none>        9411/TCP
```

The `jaeger-collector` service listens on port `4317` for OpenTelemetry traces over gRPC. Both the ingress gateway and ztunnel will send to this endpoint.

## Step 2: Configure the extension provider

Istio uses [extension providers](https://istio.io/latest/docs/reference/config/istio.mesh.v1alpha1/#MeshConfig-ExtensionProvider) in `meshConfig` to define where Envoy-based proxies (the ingress gateway and waypoints) send traces. Add an OpenTelemetry provider pointing to the Jaeger collector by patching the `istio` ConfigMap:

```bash
kubectl get configmap istio -n istio-system --context $KUBECONTEXT_CLUSTER1 -o json | \
jq '.data.mesh = ((.data.mesh | rtrimstr("\n")) + "\nextensionProviders:\n- name: jaeger-tracing\n  opentelemetry:\n    port: 4317\n    service: jaeger-collector.istio-system.svc.cluster.local\n")' | \
kubectl apply --context $KUBECONTEXT_CLUSTER1 -f -
```

istiod hot-reloads the ConfigMap within a few seconds. Confirm the extension provider is present:

```bash
sleep 5

kubectl get configmap istio -n istio-system --context $KUBECONTEXT_CLUSTER1 \
  -o jsonpath='{.data.mesh}' | grep -A5 extensionProviders
```

Expected output:

```
extensionProviders:
- name: jaeger-tracing
  opentelemetry:
    port: 4317
    service: jaeger-collector.istio-system.svc.cluster.local
```

## Step 3: Configure ztunnel L7 tracing

The Solo distribution of Istio ships with L7 observability enabled in ztunnel by default. You need to point ztunnel's tracing exporter at the Jaeger collector instead of the default Gloo telemetry pipeline endpoint.

Upgrade the ztunnel Helm release with the updated OTLP endpoint:

```bash
helm upgrade --kube-context $KUBECONTEXT_CLUSTER1 ztunnel \
  oci://us-docker.pkg.dev/soloio-img/istio-helm/ztunnel \
  -n istio-system \
  --version=$ISTIO_VERSION-solo \
  --reuse-values \
  --set 'l7Telemetry.distributedTracing.otlpEndpoint=http://jaeger-collector.istio-system:4317'
```

Confirm the ConfigMap was updated with the correct endpoint:

```bash
kubectl get configmap istio-ztunnel -n istio-system --context $KUBECONTEXT_CLUSTER1 \
  -o jsonpath='{.data.l7_config\.yaml}' | grep otlpEndpoint
```

Expected output:

```
      otlpEndpoint: http://jaeger-collector.istio-system:4317
```

The Helm upgrade updates the `istio-ztunnel` ConfigMap but does not automatically restart ztunnel pods (the DaemonSet pod template does not include a config checksum annotation). Restart the DaemonSet to load the new endpoint:

```bash
kubectl rollout restart ds/ztunnel -n istio-system --context $KUBECONTEXT_CLUSTER1

kubectl rollout status ds/ztunnel -n istio-system \
  --watch --timeout=90s --context $KUBECONTEXT_CLUSTER1
```

## Step 4: Enable tracing at the ingress gateway

With the extension provider defined and ztunnel configured, use the [Telemetry API](https://istio.io/latest/docs/tasks/observability/distributed-tracing/telemetry-api/) to start traces at the ingress gateway.

Apply a `Telemetry` resource targeting the `ingress` gateway deployed in lab `004`:

```bash
kubectl apply --context $KUBECONTEXT_CLUSTER1 -f - <<EOF
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: tracing-ingress
  namespace: istio-system
spec:
  targetRefs:
  - kind: Gateway
    name: ingress
    group: gateway.networking.k8s.io
  tracing:
  - providers:
    - name: jaeger-tracing
    randomSamplingPercentage: 100
EOF
```

`randomSamplingPercentage: 100` captures every request — appropriate for a workshop environment. In production, values between 1–10% are typical.

Verify the Telemetry resource was created:

```bash
kubectl get telemetry -n istio-system --context $KUBECONTEXT_CLUSTER1
```

Expected output:

```
NAME              AGE
tracing-ingress   5s
```

## Step 5: Enable tracing at the waypoints

Waypoints are Envoy-based proxies that enforce L7 policy at service boundaries. Like the ingress gateway, they can participate in distributed traces as `CHILD_OF` spans, capturing the time spent at each waypoint hop.

Apply a `Telemetry` resource in each namespace that has a waypoint. The Bookinfo application uses waypoints in `bookinfo-frontends` and `bookinfo-backends`:

```bash
kubectl apply --context $KUBECONTEXT_CLUSTER1 -f - <<EOF
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: tracing-waypoint
  namespace: bookinfo-frontends
spec:
  targetRefs:
  - kind: Gateway
    name: waypoint
    group: gateway.networking.k8s.io
  tracing:
  - providers:
    - name: jaeger-tracing
    randomSamplingPercentage: 100
---
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: tracing-waypoint
  namespace: bookinfo-backends
spec:
  targetRefs:
  - kind: Gateway
    name: waypoint
    group: gateway.networking.k8s.io
  tracing:
  - providers:
    - name: jaeger-tracing
    randomSamplingPercentage: 100
EOF
```

Verify both Telemetry resources were created:

```bash
kubectl get telemetry -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1
kubectl get telemetry -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1
```

Expected output:

```
NAME               AGE
tracing-waypoint   5s

NAME               AGE
tracing-waypoint   5s
```

## Step 6: Generate traffic

Get the external IP of the ingress gateway service:

```bash
export GATEWAY_IP=$(kubectl get svc ingress-istio -n istio-system \
  --context $KUBECONTEXT_CLUSTER1 \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Gateway IP: $GATEWAY_IP"
```

> **Note:** If your cloud provider returns a hostname instead of an IP (for example, AWS ELB), use:
> ```bash
> export GATEWAY_IP=$(kubectl get svc ingress-istio -n istio-system \
>   --context $KUBECONTEXT_CLUSTER1 \
>   -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
> ```

Check if your HTTPRoute from lab `004` requires a specific `Host` header:

```bash
kubectl get httproute bookinfo-route -n bookinfo-frontends \
  --context $KUBECONTEXT_CLUSTER1 \
  -o jsonpath='{.spec.hostnames}'
```

If this returns a hostname (for example, `["bookinfo.glootest.com"]`), set it:

```bash
export BOOKINFO_HOST="bookinfo.glootest.com"  # Replace with your hostname, or leave empty if none
```

Send several requests to the Bookinfo productpage:

```bash
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "Request $i: HTTP %{http_code}\n" \
    ${BOOKINFO_HOST:+-H "Host: $BOOKINFO_HOST"} \
    http://$GATEWAY_IP/productpage
done
```

Expected output:

```
Request 1: HTTP 200
Request 2: HTTP 200
...
Request 10: HTTP 200
```

> **Troubleshooting:** If you receive `HTTP 404`, your HTTPRoute requires a `Host` header. Set `BOOKINFO_HOST` above and re-run.

## Step 7: View traces in Jaeger

Open the Jaeger UI with `istioctl`:

```bash
./solo-istioctl dashboard jaeger --context $KUBECONTEXT_CLUSTER1
```

This opens the Jaeger UI in your browser (typically at `http://localhost:16686`).

### Full trace view

1. From the **Service** dropdown, select `ingress-istio.istio-system`.
2. Click **Find Traces**.

Each trace represents one request to the productpage and will show **10 spans** covering the full request path from ingress gateway through waypoints to backend services:

| Service | Operation | Ref type | Description |
|---|---|---|---|
| `ingress-istio.istio-system` | `productpage.bookinfo-frontends...:9080/*` | root | Inbound request at the ingress gateway |
| `ingress-istio.istio-system` | `router outbound\|9080\|...` | `CHILD_OF` | Egress span: forwarding to productpage waypoint |
| `productpage.bookinfo-frontends.mesh.internal` | `productpage...:9080/*` | `CHILD_OF` | Waypoint (bookinfo-frontends): L7 policy enforcement |
| `ztunnel` | `inbound GET /productpage` | `FOLLOWS_FROM` | ztunnel: tunnel segment from waypoint → productpage pod |
| `ztunnel` | `outbound GET /details/0` | `FOLLOWS_FROM` | ztunnel: tunnel segment from productpage → details waypoint |
| `details.bookinfo-backends.mesh.internal` | `details...:9080/*` | `CHILD_OF` | Waypoint (bookinfo-backends): L7 policy enforcement for details |
| `ztunnel` | `inbound GET /details/0` | `FOLLOWS_FROM` | ztunnel: tunnel segment from waypoint → details pod |
| `ztunnel` | `outbound GET /reviews/0` | `FOLLOWS_FROM` | ztunnel: tunnel segment from productpage → reviews waypoint |
| `reviews.bookinfo-backends.svc.cluster.local` | `reviews...:9080/*` | `CHILD_OF` | Waypoint (bookinfo-backends): L7 policy enforcement for reviews |
| `ztunnel` | `inbound GET /reviews/0` | `FOLLOWS_FROM` | ztunnel: tunnel segment from waypoint → reviews pod |

> **What you are seeing:** The ingress gateway (Envoy) initiates the trace. Waypoint proxies (Envoy) participate as `CHILD_OF` spans — they sit in the call path and enforce L7 policy. ztunnel spans use `FOLLOWS_FROM` — they are transparent tunnel proxies that observe the request context without participating in the call stack. Together, the three layers provide complete end-to-end observability from gateway through policy enforcement to the backend pods.

### Searching by service

You can also search by individual services in the **Service** dropdown:
- `ztunnel` — shows all ztunnel transport tunnel segments
- `productpage.bookinfo-frontends.mesh.internal` — shows spans from the bookinfo-frontends waypoint
- `details.bookinfo-backends.mesh.internal` — shows spans from the bookinfo-backends waypoint for details
- `reviews.bookinfo-backends.svc.cluster.local` — shows spans from the bookinfo-backends waypoint for reviews

## Cleanup

Remove the Telemetry resources to disable tracing at the gateway and waypoints:

```bash
kubectl delete telemetry tracing-ingress -n istio-system --context $KUBECONTEXT_CLUSTER1
kubectl delete telemetry tracing-waypoint -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1
kubectl delete telemetry tracing-waypoint -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1
```

Revert ztunnel to the default OTLP endpoint and restart to apply:

```bash
helm upgrade --kube-context $KUBECONTEXT_CLUSTER1 ztunnel \
  oci://us-docker.pkg.dev/soloio-img/istio-helm/ztunnel \
  -n istio-system \
  --version=$ISTIO_VERSION-solo \
  --reuse-values \
  --set 'l7Telemetry.distributedTracing.otlpEndpoint=http://gloo-telemetry-collector.gloo-mesh:4317'

kubectl rollout restart ds/ztunnel -n istio-system --context $KUBECONTEXT_CLUSTER1
kubectl rollout status ds/ztunnel -n istio-system --watch --timeout=90s --context $KUBECONTEXT_CLUSTER1
```

Remove the extension provider from the `istio` ConfigMap:

```bash
kubectl get configmap istio -n istio-system --context $KUBECONTEXT_CLUSTER1 -o json | \
jq '.data.mesh |= gsub("\nextensionProviders:([^\n]|\n[- ][^\n]*)*\n?"; "\n")' | \
kubectl apply --context $KUBECONTEXT_CLUSTER1 -f -
```

Optionally remove Jaeger:

```bash
ISTIO_MINOR=$(echo $ISTIO_VERSION | cut -d. -f1,2)

kubectl delete --context $KUBECONTEXT_CLUSTER1 \
  -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_MINOR}/samples/addons/jaeger.yaml
```

## Next Steps

At this point we have completed the following objectives:
- Deployed Jaeger and configured Istio to send OpenTelemetry traces to it
- Enabled trace sampling at the ingress gateway using the Telemetry API
- Enabled trace sampling at the waypoints in each Bookinfo namespace
- Configured ztunnel to export L7 trace spans using the Solo distribution's built-in OTLP support
- Observed a 10-span trace covering the full request path: ingress gateway → waypoints (L7 policy) → ztunnel tunnels → backend pods
