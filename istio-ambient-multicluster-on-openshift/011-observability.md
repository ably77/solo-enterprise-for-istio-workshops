# Observability — Inspecting Istio Ambient Metrics

# Objectives
- Inspect ztunnel metrics to observe L4 mTLS connection data and L7 request telemetry
- Inspect istiod metrics to observe control plane health

## Prerequisites
This lab assumes you have completed lab `010`. The waypoint for `bookinfo-backends` must be deployed and the namespace enrolled in the mesh.

Ensure the following environment variables are set:
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

## Cleanup

No persistent Kubernetes resources were created in this lab. The port-forwards were stopped inline above.

The waypoint deployed in lab `010` remains in place for lab `012`.

## Next Steps
At this point we have completed the following objectives:
- Inspected ztunnel metrics to observe L4 mTLS connections and L7 HTTP request telemetry
- Inspected istiod metrics to observe control plane config push activity and proxy convergence latency

In the next step `012` we will configure egress with a waypoint.
