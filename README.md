# Solo Enterprise for Istio Workshops

Hands-on workshops for deploying and operating **Solo Enterprise for Istio** with Ambient Mesh. Workshops cover zero-trust security, ingress, egress control, observability, multi-cluster routing, and global service discovery using the Bookinfo sample application.

![](/images/intro-1.png)

## Workshops

| Workshop | Platform | Clusters | Description |
|---|---|---|---|
| [`istio-ambient-single-cluster`](istio-ambient-single-cluster/) | Standard Kubernetes | 1 | Single-cluster ambient mesh on standard Kubernetes (GKE) — zero trust, ingress, egress, waypoints, observability. |
| [`istio-ambient-single-cluster-on-openshift`](istio-ambient-single-cluster-on-openshift/) | OpenShift | 1 | Single-cluster ambient mesh on OpenShift — ingress, egress, waypoints, observability with OpenShift User Workload Monitoring. |
| [`istio-ambient-multicluster-on-openshift`](istio-ambient-multicluster-on-openshift/) | OpenShift | 2 | Ambient mesh across two OpenShift clusters — multicluster routing, global service discovery, failover, segments, global aliases, zero-trust access control, egress, waypoints, observability, Gloo UI. |
| [`istio-ambient-multicluster`](istio-ambient-multicluster/) | Standard Kubernetes | 2 | Ambient mesh across two standard Kubernetes clusters (tested on GKE) — multicluster routing, global service discovery, failover, segments, global aliases, zero-trust access control, egress, waypoints, observability, Gloo UI. |
| [`istio-oss-sidecar-to-enterprise-ambient`](istio-oss-sidecar-to-enterprise-ambient/) | Standard Kubernetes | 1 | In-place migration from OSS Istio sidecar to Solo Enterprise Ambient, ingress, egress, waypoints, observability, zero-trust access control |

## Use Cases Covered

| Use Case | Single-cluster (K8s) | Single-cluster OSS→Ambient (K8s) | Multicluster (K8s) | Single-cluster (OCP) | Multicluster (OCP) |
|---|:---:|:---:|:---:|:---:|:---:|
| Sidecars | | ✓ | | | |
| Migration | | ✓ | | | |
| Zero Trust (mTLS) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ingress | ✓ | ✓ | ✓ | ✓ | ✓ |
| Egress Control | ✓ | ✓ | ✓ | ✓ | ✓ |
| Waypoints | ✓ | ✓ | ✓ | ✓ | ✓ |
| Observability | ✓ | ✓ | ✓ | ✓ | ✓ |
| Multi-cluster routing | | | ✓ | | ✓ |
| Global service discovery | | | ✓ | | ✓ |
| High Availability / Failover | | | ✓ | | ✓ |
| Multitenancy (segments) | | | ✓ | | ✓ |
| Global Aliases | | | ✓ | | ✓ |

## Versions

| Component | Version |
|---|---|
| Istio (Solo) | 1.29.0-solo |
| Gloo Platform | 2.12.0 |
| Kubernetes | ≥ 1.29 |
| OpenShift | 4.16.0 – 4.19.x |

## Prerequisites

- A valid Solo.io license key
- `solo-istioctl` ([install guide](istio-ambient-single-cluster-on-openshift/000-tools.md))
- `helm`
- One or two clusters depending on the workshop (see table above)
- `meshctl` — multicluster workshops only ([install guide](istio-ambient-multicluster-on-openshift/000-tools.md))

## Getting Started

1. Clone this repo
2. Obtain a Solo.io trial license key
3. Choose a workshop from the table above
4. Follow the labs in order starting with `000-introduction.md`
