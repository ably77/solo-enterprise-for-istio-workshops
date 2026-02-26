# Istio Ambient Multicluster Workshop — Kubernetes

Hands-on workshop for deploying Solo.io's Enterprise Istio Ambient Mesh across two Kubernetes clusters, using the Bookinfo sample application.

## Versions

| Component | Version |
|---|---|
| Istio (Solo) | 1.29.0-solo |
| Gloo Platform | 2.12.0 |
| Kubernetes | ≥ 1.29 |

## Prerequisites

- A valid Solo.io license key
- `solo-istioctl` — see [000-tools.md](000-tools.md)
- `meshctl` — see [000-tools.md](000-tools.md)
- `helm`
- Two Kubernetes clusters (≥ 1.29)
- (Optional) Vegeta for load generation — see [000-tools.md](000-tools.md)

## Labs

| Lab | Topic |
|---|---|
| [000-introduction.md](000-introduction.md) | Overview and objectives |
| [000-prerequisites.md](000-prerequisites.md) | Requirements and image list |
| [000-tools.md](000-tools.md) | Tool installation |
| [001-deploy-bookinfo.md](001-deploy-bookinfo.md) | Deploy the Bookinfo application |
| [002-install-istio-on-cluster1.md](002-install-istio-on-cluster1.md) | Install Istio Ambient on cluster1 |
| [003-install-istio-on-cluster2.md](003-install-istio-on-cluster2.md) | Install Istio Ambient on cluster2 |
| [004-enroll-apps-in-the-mesh.md](004-enroll-apps-in-the-mesh.md) | Enroll workloads in the mesh |
| [005-expose-bookinfo.md](005-expose-bookinfo.md) | Configure the ingress gateway |
| [006-multicluster.md](006-multicluster.md) | Link the clusters and configure failover |
| [007-segments.md](007-segments.md) | Namespace isolation with Segments |
| [008-global-aliases.md](008-global-aliases.md) | Global service aliases |
| [009-mesh-access-control.md](009-mesh-access-control.md) | Zero-trust access control policies |
| [010-egress.md](010-egress.md) | Egress control with a waypoint |
| [011-install-gme-control-plane.md](011-install-gme-control-plane.md) | Deploy Gloo Mesh Enterprise UI |
| [012-cleanup.md](012-cleanup.md) | Teardown |

## Getting Started

Follow the labs in order starting with [000-introduction.md](000-introduction.md).
