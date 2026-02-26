# OSS Istio Sidecar to Solo Enterprise Ambient Workshop

A hands-on migration workshop: start with open-source Istio in **sidecar mode** (a common production starting point), deploy the Bookinfo sample application with sidecar injection, then perform an **in-place upgrade** to Solo Enterprise Istio Ambient. Experience what a real production migration looks like — including the coexistence period and namespace-by-namespace migration pattern.

![](/images/intro-1.png)

## Workshop Overview

| | |
|---|---|
| **Platform** | Kubernetes (single cluster) |
| **Starting point** | OSS Istio 1.26.8 (sidecar mode) |
| **Target** | Solo Istio 1.29.0-solo (ambient mode) |
| **Gloo Platform** | 2.12.0 |

## Three-Phase Journey

| Phase | Labs | Description |
|---|---|---|
| **Phase 1 — Start with OSS Istio** | `001`–`003` | Install community Istio in sidecar mode, deploy Bookinfo, expose via ingress |
| **Phase 2 — Migrate to Solo Ambient** | `004`–`005` | In-place upgrade to Solo Istio Ambient; migrate namespaces from sidecar → ambient |
| **Phase 3 — Zero-Trust & L7** | `006`–`009` | AuthorizationPolicy, waypoints, traffic management, observability, egress control |

## Lab Sequence

```
000-introduction.md               Overview and migration narrative
000-prerequisites.md              Requirements and image list
000-tools.md                      Tool installation
001-install-oss-istio.md          Install OSS Istio in sidecar mode
002-deploy-bookinfo-with-sidecars.md  Deploy Bookinfo with sidecar injection (2/2 pods)
003-expose-bookinfo.md            Expose via Gateway API ingress
004-upgrade-to-solo-ambient.md    In-place upgrade to Solo Istio Ambient
005-migrate-namespaces.md         Move namespaces from sidecar → ambient (1/1 pods)
006-mesh-access-control.md        Zero-trust AuthorizationPolicy
007-waypoints.md                  L7 traffic management with waypoints
008-observability.md              ztunnel and istiod metrics
009-egress.md                     Egress control with a shared waypoint
010-cleanup.md                    Teardown
```

## Key Teaching Moments

- **Before migration:** Bookinfo pods show `2/2 READY` (app + Envoy sidecar)
- **After migration:** Bookinfo pods show `1/1 READY` (app only — ztunnel handles mTLS at the node level)
- **During coexistence:** Both sidecar and ambient workloads run simultaneously — the upgrade is non-disruptive

## Versions

| Component | Version |
|---|---|
| OSS Istio (start) | 1.26.8 |
| Solo Istio (target) | 1.29.0-solo |
| Gloo Platform | 2.12.0 |
| Gateway API | v1.4.0 |
| Kubernetes | ≥ 1.29 |

## Prerequisites

- A valid Solo.io license key (`$SOLO_TRIAL_LICENSE_KEY`)
- `helm`
- A Kubernetes cluster ≥ 1.29
- `openssl` (macOS/Linux built-in; Windows users: WSL or Git Bash)

## Getting Started

1. Clone this repo
2. Obtain a Solo.io trial license key
3. Follow the labs in order starting with `000-introduction.md`
