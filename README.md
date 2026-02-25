# Solo Enterprise for Istio Workshops

Hands-on workshops for deploying and operating **Solo.io's Enterprise Istio** with Ambient Mesh in multicluster environments. Workshops cover zero-trust security, multi-cluster routing, global service discovery, and observability using the Bookinfo sample application.

## Workshops

| Workshop | Platform | Description |
|---|---|---|
| [`istio-ambient-multicluster`](istio-ambient-multicluster/) | Kubernetes | Ambient mesh across two Kubernetes clusters |
| [`istio-ambient-multicluster-on-openshift`](istio-ambient-multicluster-on-openshift/) | OpenShift | Ambient mesh across two OpenShift clusters |

## Use Cases Covered

- Zero Trust (mTLS)
- Ingress
- Observability
- Multi-cluster routing
- Global service discovery
- High Availability / Failover
- Egress Control

## Versions

| Component | Version |
|---|---|
| Istio (Solo) | 1.29.0-solo |
| Gloo Platform | 2.12.0 |
| Kubernetes | ≥ 1.29 |
| OpenShift | 4.16.0 – 4.19.x |

## Prerequisites

- A valid Solo.io license key
- `solo-istioctl` ([install guide](istio-ambient-multicluster/000-tools.md))
- `meshctl` ([install guide](istio-ambient-multicluster/000-tools.md))
- `helm`
- Two clusters (Kubernetes ≥ 1.29 or OpenShift 4.16+)

## Workshop Structure

Each workshop follows the same numbered lab sequence:

```
000-introduction.md         Overview and objectives
000-prerequisites.md        Requirements and image list
000-tools.md                Tool installation
001-deploy-bookinfo.md      Deploy sample application
002-install-istio-*.md      Install Istio on cluster 1
003-install-istio-*.md      Install Istio on cluster 2
004-enroll-apps-*.md        Enroll apps in the mesh
005-expose-bookinfo.md      Configure ingress gateway
006-multicluster.md         Link the clusters
007-segments.md             Traffic segmentation
008-global-aliases.md       Global service aliases
009-mesh-access-control.md  Zero-trust access policies
010-egress.md               Egress control
011-install-gme-*.md        Install Gloo Mesh Enterprise UI
012-cleanup.md              Teardown
```

## Getting Started

1. Clone this repo
2. Obtain a Solo.io trial license key
3. Choose a workshop directory based on your platform
4. Follow the labs in order starting with `000-introduction.md`
