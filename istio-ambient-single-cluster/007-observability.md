# Observability — Inspecting Istio Ambient Metrics

# Objectives
- Inspect ztunnel metrics to observe L4 mTLS connection data and L7 request telemetry
- Inspect istiod metrics to observe control plane health
- (Optional) Configure persistent Prometheus scraping via PodMonitors

## Prerequisites
- This lab assumes you have completed setup from labs `000-003`

## Set environment variables

```bash
export CLUSTER1=cluster1
```

## Background

Solo Istio Ambient enables `L7_ENABLED: "true"` on ztunnel (configured in lab `002`). This means ztunnel emits both **L4 TCP** and **L7 HTTP** metrics from a single endpoint — no waypoint-specific scrape is needed for request-level telemetry.

Each Istio component exposes a Prometheus-format `/metrics` endpoint. `kubectl port-forward` and `curl` are sufficient for ad-hoc inspection without deploying a full Prometheus stack.

| Component | Port | Path | What it shows |
|---|---|---|---|
| ztunnel (DaemonSet pod) | 15020 | `/metrics` | L4 TCP + L7 HTTP metrics (mTLS, request counts, response codes, latency) |
| istiod | 15014 | `/metrics` | Control plane metrics: config push latency, connected proxies |

## ztunnel Metrics (L4 + L7)

ztunnel is a DaemonSet — one pod per node. Get any ztunnel pod name:
```bash
ZTUNNEL_POD=$(kubectl get pods -n istio-system -l app=ztunnel \
  --context $CLUSTER1 -o jsonpath='{.items[0].metadata.name}')
echo $ZTUNNEL_POD
```

Port-forward to the ztunnel pod's metrics port:
```bash
kubectl port-forward -n istio-system $ZTUNNEL_POD 15020:15020 --context $CLUSTER1 &
PORT_FORWARD_PID=$!
sleep 2
```

Generate traffic through the mesh so that ztunnel records connections and requests:
```bash
for i in $(seq 1 5); do
  kubectl exec deploy/productpage-v1 -n bookinfo-frontends --context $CLUSTER1 -- \
    python3 -c "import urllib.request, json; print(json.dumps(json.load(urllib.request.urlopen('http://reviews.bookinfo-backends:9080/reviews/0')), indent=2))"
done
```

Inspect L4 TCP connection metrics — confirm mTLS is in use:
```bash
curl -s localhost:15020/metrics | grep istio_tcp_connections_opened_total
```

You should see entries tagged with `security_policy="mutual_tls"`, confirming all connections inside the mesh are mTLS-encrypted:
```
istio_tcp_connections_opened_total{...security_policy="mutual_tls",...} 5
```

Inspect L7 HTTP request metrics — observe per-request labels:
```bash
curl -s localhost:15020/metrics | grep 'istio_requests_total'
```

The output shows L7 labels including `response_code`, `source_workload`, and `destination_service`:
```
istio_requests_total{connection_security_policy="mutual_tls",destination_service="reviews.bookinfo-backends.svc.cluster.local",reporter="source",request_protocol="http",response_code="200",source_workload="productpage-v1",...} 5
```

Stop the port-forward:
```bash
kill $PORT_FORWARD_PID
```

## istiod Metrics

Port-forward to istiod's metrics port:
```bash
kubectl port-forward -n istio-system svc/istiod 15014:15014 --context $CLUSTER1 &
ISTIOD_PID=$!
sleep 2
```

Inspect config distribution counters — how many xDS pushes istiod has performed:
```bash
curl -s localhost:15014/metrics | grep pilot_xds_pushes
```

Example output:
```
pilot_xds_pushes{type="cds"} 42
pilot_xds_pushes{type="eds"} 38
pilot_xds_pushes{type="lds"} 21
pilot_xds_pushes{type="rds"} 19
```

Inspect proxy convergence latency — how long it takes for proxies to acknowledge config updates:
```bash
curl -s localhost:15014/metrics | grep pilot_proxy_convergence_time
```

Example output:
```
pilot_proxy_convergence_time_bucket{le="0.1"} 120
pilot_proxy_convergence_time_bucket{le="0.5"} 140
pilot_proxy_convergence_time_count 142
pilot_proxy_convergence_time_sum 8.3
```

Stop the port-forward:
```bash
kill $ISTIOD_PID
```

## Persistent Scraping with Prometheus Operator (Optional)

The port-forward approach above is useful for ad-hoc inspection. For persistent, Prometheus-based scraping, use `PodMonitor` resources from the [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator). This is available in any cluster running `kube-prometheus-stack` or a compatible Prometheus Operator deployment.

The Istio Ambient components expose Prometheus metrics on the following ports:

| Component | Namespace | Pod label | Port | What it shows |
|---|---|---|---|---|
| ztunnel | `istio-system` | `app=ztunnel` | 15020 | L4 TCP + L7 HTTP metrics |
| istiod | `istio-system` | `app=istiod` | 15014 | Control plane health and xDS push metrics |
| Ingress gateway | `istio-system` | `gateway.networking.k8s.io/gateway-name=ingress` | 15020 | Envoy proxy request/response metrics |

### PodMonitor for ztunnel

```bash
kubectl apply --context $CLUSTER1 -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-ztunnel
  namespace: istio-system
spec:
  namespaceSelector:
    matchNames:
      - istio-system
  podMetricsEndpoints:
    - port: ztunnel-stats
      path: /metrics
  selector:
    matchLabels:
      app: ztunnel
EOF
```

### PodMonitor for istiod

istiod exposes control plane metrics (xDS push counts, proxy convergence latency, connected proxies) on port `15014`:

```bash
kubectl apply --context $CLUSTER1 -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-control-plane
  namespace: istio-system
spec:
  namespaceSelector:
    matchNames:
      - istio-system
  podMetricsEndpoints:
    - port: http-monitoring
      path: /metrics
  selector:
    matchLabels:
      app: istiod
EOF
```

### PodMonitor for the ingress gateway

The ingress gateway pod (an Envoy proxy) exposes request/response metrics on port `15020`. When a Gateway is provisioned via the Gateway API, the controller stamps the pod with `gateway.networking.k8s.io/gateway-name=<name>` — use that label as the selector:

```bash
kubectl apply --context $CLUSTER1 -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-ingress-gateway
  namespace: istio-system
spec:
  namespaceSelector:
    matchNames:
      - istio-system
  podMetricsEndpoints:
    - port: metrics
      path: /metrics
  selector:
    matchLabels:
      gateway.networking.k8s.io/gateway-name: ingress
EOF
```

### Querying metrics by component

When Prometheus scrapes via PodMonitor it attaches `pod` and `namespace` labels from the scraped pod. Use these to distinguish which component a metric is coming from.

**ztunnel** — pods in `istio-system`, names prefixed `ztunnel-`:
```
istio_requests_total{namespace="istio-system", pod=~"ztunnel-.*"}
```
```
istio_tcp_connections_opened_total{namespace="istio-system", pod=~"ztunnel-.*"}
```

**istiod** — pods in `istio-system`, names prefixed `istiod-`:
```
pilot_xds_pushes{namespace="istio-system", pod=~"istiod-.*"}
```

**Ingress gateway** — pods in `istio-system`, names prefixed `ingress-istio-`:
```
istio_requests_total{namespace="istio-system", pod=~"ingress-istio-.*"}
```

## Next Steps
At this point we have completed the following objectives:
- Inspected ztunnel metrics to observe L4 mTLS connections and L7 HTTP request telemetry
- Inspected istiod metrics to observe control plane config push activity and proxy convergence latency
- (Optional) Configured PodMonitors for persistent Prometheus scraping of all Istio Ambient components

In the next step `008` we will clean up all workshop resources.
