# Istio Ambient Single Cluster Workshop

Hands-on workshop for deploying Solo Enterprise for Istio Ambient Mesh on a single standard Kubernetes cluster (GKE or any CNCF-conformant cluster), using the Bookinfo sample application.

## Versions

| Component | Version |
|---|---|
| Istio (Solo) | 1.29.0-solo |
| Kubernetes | >= 1.29 |

## Prerequisites

- A valid Solo.io license key
- `solo-istioctl` — see [000-tools.md](000-tools.md)
- `helm`
- `kubectl`
- One Kubernetes cluster (>= 1.29)
- (Optional) Vegeta for load generation — see [000-tools.md](000-tools.md)

## Labs

| Lab | Topic |
|---|---|
| [000-introduction.md](000-introduction.md) | Overview and objectives |
| [000-prerequisites.md](000-prerequisites.md) | Requirements and image list |
| [000-tools.md](000-tools.md) | Tool installation |
| [001-deploy-bookinfo.md](001-deploy-bookinfo.md) | Deploy the Bookinfo application |
| [002-install-istio.md](002-install-istio.md) | Install Solo Istio Ambient |
| [003-enroll-apps-in-the-mesh.md](003-enroll-apps-in-the-mesh.md) | Enroll workloads in the mesh |
| [004-expose-bookinfo.md](004-expose-bookinfo.md) | Configure the ingress gateway |
| [005-egress.md](005-egress.md) | Egress control with a waypoint |
| [006-waypoints.md](006-waypoints.md) | L7 traffic management with waypoints |
| [007-observability.md](007-observability.md) | Observability — inspecting Istio Ambient metrics |
| [008-cleanup.md](008-cleanup.md) | Teardown |

## Getting Started

Follow the labs in order starting with [000-introduction.md](000-introduction.md).
