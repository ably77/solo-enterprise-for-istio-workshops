# Ports Used in an Istio Ambient Mesh

**Reference page.** Ports an ambient mesh requires on firewalls, cloud security groups, and Kubernetes `NetworkPolicy`. It applies to every workshop in this repository.

## Required ports: 15008 and 15012

| Port | Used for |
|---|---|
| **15008** | The HBONE mTLS tunnel between ztunnels, waypoints, and east-west gateways. All data plane traffic in the mesh uses it. |
| **15012** | istiod's xDS and CA services over TLS/mTLS. Proxies fetch their configuration and certificates here, and clusters peer over it. |

## Data plane (ztunnel, waypoints, gateways)

| Port | Protocol | Component | Purpose | Reachable from outside the pod |
|---|---|---|---|---|
| 15008 | HTTP/2 | ztunnel, waypoint, east-west gateway | HBONE mTLS tunnel, carrying all mesh data plane traffic | Yes |
| 15001 | TCP | Envoy proxy | Envoy outbound | Yes |
| 15006 | TCP | Envoy proxy | Envoy inbound | Yes |
| 15000 | TCP | Envoy proxy (waypoint, gateway) | Envoy admin port: commands and diagnostics | No, pod-internal only |
| 15002 | TCP | Envoy proxy | Listen port for failure detection | No, pod-internal only |
| 15004 | HTTP | Envoy proxy | Debug port | No, pod-internal only |
| 15053 | DNS | Proxy | DNS port, when DNS capture is enabled | No, pod-internal only |

## Telemetry and health

| Port | Protocol | Component | Purpose | Reachable from outside the pod |
|---|---|---|---|---|
| 15020 | HTTP | Proxy / agent | Merged Prometheus telemetry | Yes |
| 15021 | HTTP | Proxy | Health checks | Yes |
| 15090 | HTTP | Envoy proxy | Envoy Prometheus telemetry | Yes |

The observability labs in each workshop scrape 15020 and 15090.

## Control plane (istiod)

| Port | Protocol | Component | Purpose | Reachable from outside the pod |
|---|---|---|---|---|
| 15012 | gRPC | istiod, east-west gateway | xDS and CA services over TLS/mTLS; multicluster peering port | Yes |
| 443 | HTTPS | istiod | Webhooks service port | Yes |
| 15017 | HTTPS | istiod | Webhook container port, forwarded from 443 | Yes |
| 15014 | HTTP | istiod | Control plane monitoring | Yes |
| 15010 | gRPC | istiod | xDS and CA services, **plaintext**, for secure networks only | Yes |
| 8080 | HTTP | istiod | Debug interface (deprecated, container port only) | Yes |

Prefer 15012 over 15010 anywhere you have a choice: 15010 carries configuration and certificate material with no transport security.

## Multicluster

The multicluster workshops peer clusters through an east-west gateway. That gateway needs exactly two ports open **inbound from the peer cluster's network**:

| Port | Carries |
|---|---|
| 15008 | HBONE data plane traffic between clusters |
| 15012 | The remote istiod's xDS and CA traffic, and service registry sync |

Ask your network team for those two rules when the clusters sit in separate VPCs, cloud accounts, or firewall zones.

## Checking what a workload listens on

To confirm any of this against your own cluster:

```bash
# Ports ztunnel exposes on a node
# (istio-ambient-multicluster-on-openshift installs ztunnel in kube-system)
kubectl -n istio-system get pod -l app=ztunnel \
  -o jsonpath='{range .items[0].spec.containers[*].ports[*]}{.name}{"\t"}{.containerPort}{"\n"}{end}'
```

```bash
# Ports istiod exposes
kubectl -n istio-system get svc istiod \
  -o jsonpath='{range .spec.ports[*]}{.name}{"\t"}{.port}{" -> "}{.targetPort}{"\n"}{end}'
```

```bash
# Ports a waypoint exposes (adjust namespace and name to your waypoint)
kubectl -n bookinfo-backends get svc waypoint \
  -o jsonpath='{range .spec.ports[*]}{.name}{"\t"}{.port}{"\n"}{end}'
```

```bash
# Ports the east-west gateway exposes (multicluster workshops)
kubectl -n istio-gateways get svc istio-eastwest \
  -o jsonpath='{range .spec.ports[*]}{.name}{"\t"}{.port}{"\n"}{end}'
```

## Sources

- Istio: [Ports used by Istio](https://istio.io/latest/docs/ops/deployment/application-requirements/#ports-used-by-istio)
- Istio: [HBONE](https://istio.io/latest/docs/ambient/architecture/hbone/)
- Istio: [Ambient mesh and Kubernetes NetworkPolicy](https://istio.io/latest/docs/ambient/usage/networkpolicy/)
- Solo: [Ambient multicluster](https://docs.solo.io/istio/1.30.x/ambient/about/multicluster/)
