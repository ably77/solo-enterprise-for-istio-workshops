# Changelog

0.1.8 - (7-22-26)
---
- Add Helm `peering` chart option for linking clusters (alongside `solo-istioctl multicluster link`) to `006-multicluster-global-mesh.md` in `istio-ambient-multicluster` and `istio-ambient-multicluster-on-openshift`
- Add bonus lab `014-add-a-third-cluster.md` to `istio-ambient-multicluster` — scale the two-cluster mesh to a third cluster, with full-mesh peering and three-way failover

0.1.7 - (7-8-26)
---
- Bump Solo Istio from `1.29.0-solo` to `1.30.2-solo` across all workshops — update `ISTIO_VERSION` in every `000-tools.md` and install lab (including the stale `1.28.3` in the two multicluster `000-tools.md`), the `helm pull`/`docker pull` version tags in every `000-prerequisites.md`, and the version tables in the top-level and per-workshop READMEs/introductions.
- Bump OSS Istio from `1.26.8` to `1.29.5`
- Bump Gateway API CRDs from `v1.4.0` to `v1.5.0` (`standard-install.yaml`) across all install labs and the workshop version table

0.1.6 - (5-18-26)
---
- Update Solo UI version to `0.4.1-2026-05-14-main-6fb46ef2`

0.1.5 - (5-14-26)
---
- Rewrite `013-install-gme-control-plane.md` → `013-install-solo-ui.md` in `istio-ambient-multicluster` and `istio-ambient-multicluster-on-openshift` — replace legacy Gloo Platform 2.12.0 control-plane install with the latest Solo Management UI (mesh product view) plus a workload-cluster relay that tunnels via Istio Ambient `mesh.internal`
- OpenShift variant: add a single Route for `solo-enterprise-ui`; drop the legacy `gloo-mesh-mgmt-server`/`gloo-telemetry-gateway` Routes and the privileged SCC rolebinding (new charts don't require them)
- Update workshop READMEs to point to the renamed lab 013
- Add `008-install-solo-ui.md` to `istio-ambient-single-cluster-on-openshift` (with OpenShift Route); renumber `008-cleanup.md` → `009-cleanup.md` and include Solo UI uninstall
- Add `009-install-solo-ui.md` to `istio-ambient-single-cluster` (port-forward only); renumber `009-cleanup.md` → `010-cleanup.md` and include Solo UI uninstall
- Update top-level README — switch workshop descriptions from "Gloo UI" to "Solo Management UI", add a Solo Management UI use-case row, replace Gloo Platform version with Solo Management UI version, drop `meshctl` prerequisite
- Update Solo UI lab images from `gloo-ui-{1,2}.png` to `solo-ui-{1,2,3}.png` across both multicluster Solo UI labs
- Add `.claude/` to `.gitignore`
- Strip `meshctl` references from all workshops (`000-prerequisites.md`, `000-tools.md`, workshop READMEs) — debug tooling for the retired Gloo Mesh Enterprise stack
- Add OpenShift OVN-Kubernetes local gateway mode (`routingViaHost: true`) prerequisite to ambient install labs — `istio-ambient-single-cluster-on-openshift/002-install-istio.md` and `istio-ambient-multicluster-on-openshift/00{2,3}-install-istio-on-cluster{1,2}.md` — without it kubelet probes to ambient-enrolled pods time out and CrashLoop on OCP IPI
- Solo UI labs on OpenShift (`istio-ambient-single-cluster-on-openshift/008-install-solo-ui.md` and `istio-ambient-multicluster-on-openshift/013-install-solo-ui.md`): pre-grant `anyuid` SCC to the `management-clickhouse` service account (ClickHouse hardcodes UID 101 which `restricted-v2` rejects), add a `clickhouse.resources` override (500m CPU / 1Gi memory request) so the pod schedules on workshop-sized clusters, and replace the incorrect "compatible with `restricted-v2`" note with the OVN-K probe-timeout warning
- Add cross-cluster DNS propagation callout after `solo-istioctl multicluster link` in `istio-ambient-multicluster-on-openshift/006-multicluster-global-mesh.md` — fresh AWS NLB hostnames take 30–90s to resolve from CoreDNS; the failover test returns 503s if attempted before the istiod peering link is established

0.1.4 - (4-8-26)
---
- Fix undefined `$CLUSTER1`/`$CLUSTER2` in `topology.istio.io/network` label commands — replace with `$MESH_NAME_CLUSTER1`/`$MESH_NAME_CLUSTER2` across all install docs
- Add KinD callout to all install docs warning that `KUBECONTEXT_CLUSTER*` should include the `kind-` prefix but `MESH_NAME_CLUSTER*` should not
- Refactor `solo-istioctl` download to extract URL into `$ISTIOCTL_URL` variable across all workshops
- Add port-forward fallback section to expose-bookinfo labs in multicluster-on-openshift, single-cluster, and single-cluster-on-openshift workshops
- Add LoadBalancer check to `SVC=` command in expose-bookinfo labs — prints warning and directs to port-forward section if IP is pending or unavailable

0.1.3 - (4-6-26)
---
- Update CA cert script to generate proper certs with CA:TRUE
- Add `008-tracing.md` lab to istio-ambient-single-cluster. Move cleanup lab to `009`

0.1.2 - (3-2-26)
---
- Add example `/envoyfilter` lab in `/istio-oss-sidecar-to-enterprise-ambient` workshop

0.1.1 - (2-27-26)
---
- Add callout to ingress labs on how to configure TLS with an HTTPS listener

0.1.0 - (2-27-26)
---
- Remove unused `MESH_NAME_CLUSTER1` variable references from `istio-oss-sidecar-to-enterprise-ambient` workshop
- Remove `MESH_NAME_CLUSTER<N>` variables in labs where it is unnecessary

0.0.15 - (2-27-26)
---
- Move Gateway service annotations to a callout
- Introduce new cluster naming variables to eliminate naming conflicts

0.0.14 - (2-27-26)
---
- Update expose bookinfo lab with gw-options extension reference example

0.0.13 - (2-27-26)
---
- README updates

0.0.12 - (2-27-26)
---
- New Workshop: Single cluster Solo Enterprise for Istio Ambient Workshop (tested on GKE)

0.0.11 - (2-27-26)
---
- Updates to main README.md

0.0.10 - (2-27-26)
---
- Updates to main README.md

0.0.9 - (2-27-26)
---
- New Workshop: Solo Enterprise for Istio Ambient Workshop on OpenShift

0.0.8 - (2-26-26)
---
- New Workshop: OSS Istio Sidecar to Solo Enterprise Ambient
- Fixes for waypoint lab in multicluster demos
- Update README.md
- Move image list into `000-prerequisites.md`

0.0.7 - (2-25-26)
---
- Add dependencies as prerequisites to each lab

0.0.6 - (2-25-26)
---
- Improvements to README.md
- Add observability lab

0.0.5 - (2-25-26)
---
- General cleanup and improvements to workshop labs
- Add instructions for generating secret for shared root of trust to `002`
- Update prerequisites
- Add images to waypoint lab

0.0.4 - (2-25-26)
---
- Add short readmes to each individual workshop
- Add new lab: `010-waypoints.md`
- Renumber/re-org labs

0.0.3 - (2-25-26)
---
- Update images for global aliases lab
- Update images for mesh access control lab
- Update images for GME lab

0.0.2 - (2-25-26)
---
- Remove `solo-istioctl` binary from repo. Instructions for install in `000-tools.md`
- Updates to images

0.0.1 - (2-25-26)
---
- Add README.md
- Update `000-prerequisites.md` and `000.introduction.md` with correct versions
- Update 001 and 002 with correct Istio Ambient versions
- Add updated images to labs
- Add objectives to `009-011`

0.0.0 - (2-25-26)
---
- First commit
  - Added workshop: `istio-ambient-multicluster`
  - Added workshop: `istio-ambient-multicluster-on-openshift`