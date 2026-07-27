# Istio Ambient Single Cluster Workshop — OpenShift

Hands-on workshop for deploying Solo Enterprise for Istio Ambient Mesh on a single OpenShift cluster, using the Bookinfo sample application.

## Versions

| Component | Version |
|---|---|
| Istio (Solo) | 1.30.2-solo |
| OpenShift | 4.16.0 – 4.19.30 (latest) |

## Prerequisites

- A valid Solo.io license key
- `solo-istioctl` — see [000-tools.md](000-tools.md)
- `helm`
- `oc` (OpenShift CLI)
- One OpenShift cluster (4.16+)
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
| [008-install-solo-ui.md](008-install-solo-ui.md) | Install the Solo Management UI |
| [009-cleanup.md](009-cleanup.md) | Teardown |

## Getting Started

Every lab runs its commands relative to this directory (`kubectl apply -f bookinfo/...`, `./solo-istioctl`), so change into it first:

```bash
cd istio-ambient-single-cluster-on-openshift
```

Then work through the labs in order, starting with [000-introduction.md](000-introduction.md).
