# Istio Ambient Multicluster Workshop — Kubernetes

Hands-on workshop for deploying Solo Enterprise for Istio Ambient Mesh across two Kubernetes clusters, using the Bookinfo sample application.

## Versions

| Component | Version |
|---|---|
| Istio (Solo) | 1.30.2-solo |
| Solo Management UI | 0.5.1 |
| Kubernetes | ≥ 1.29 |

## Prerequisites

- A valid Solo.io license key
- `solo-istioctl` — see [000-tools.md](000-tools.md)
- `helm`
- Two Kubernetes clusters (≥ 1.29)
- (Optional) A third Kubernetes cluster (≥ 1.29) for the bonus lab [014-add-a-third-cluster.md](014-add-a-third-cluster.md)
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
| [006-multicluster-global-mesh.md](006-multicluster-global-mesh.md) | Link the clusters and configure failover |
| [007-segments.md](007-segments.md) | Namespace isolation with Segments |
| [008-global-aliases.md](008-global-aliases.md) | Global service aliases |
| [009-mesh-access-control.md](009-mesh-access-control.md) | Zero-trust access control policies |
| [010-waypoints.md](010-waypoints.md) | L7 traffic management with waypoints |
| [011-observability.md](011-observability.md) | Observability — inspecting Istio Ambient metrics |
| [012-egress.md](012-egress.md) | Egress control with a waypoint |
| [013-install-solo-ui.md](013-install-solo-ui.md) | Install the Solo Management UI |
| [014-add-a-third-cluster.md](014-add-a-third-cluster.md) | Bonus: scale the mesh out to a third cluster |
| [015-cleanup.md](015-cleanup.md) | Teardown |

## Getting Started

Every lab runs its commands relative to this directory (`kubectl apply -f bookinfo/...`, `./solo-istioctl`), so change into it first:

```bash
cd istio-ambient-multicluster
```

Then work through the labs in order, starting with [000-introduction.md](000-introduction.md).
