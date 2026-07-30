# Changelog

0.2.0 - (7-30-26)
---
- add new lab: `/istio-ambient-single-cluster/010-grpc-loadbalancing.md`
- add new lab: `/istio-ambient-multicluster/015-grpc-loadbalancing.md`

0.1.9 - (7-27-26)
---
- Update `.gitignore`
- Update Solo UI to `0.5.1`, and replace the remaining Gloo Platform 2.12.0 references across both multicluster workshops and `istio-oss-sidecar-to-enterprise-ambient`
- Add a `clickhouse.resources` override (500m CPU / 1Gi) to the two Kubernetes Solo UI labs, since the chart defaults of 2 CPU and 3Gi leave the pod `Pending` on workshop-sized clusters
- Warn that a Segment label on `istio-system` breaks the Solo UI relay, with a blocking prerequisite in `013` and `014` and a clearer cleanup heading in `007`
- Select the ztunnel pod on the same node as `productpage` across all five observability labs, because each ztunnel reports only its own node's traffic and the previous `items[0]` pick often returned nothing
- Read ztunnel metrics from `kube-system` in `istio-ambient-multicluster-on-openshift/011-observability.md`, which is where that workshop installs ztunnel
- Rename the license prose to "Solo Trial License Key" across all five workshops
- Replace the no-op `export SOLO_TRIAL_LICENSE_KEY=$SOLO_TRIAL_LICENSE_KEY` with a placeholder and a guard across all 9 install labs, since an empty license installs cleanly and only fails later at peering
- Correct 12 inverted `region` values in the `peering` configs, which named the local cluster instead of the remote peer and left locality-priority routing disengaged
- Derive `addressType` in the peering values from the east-west gateway address instead of hardcoding `IPAddress`
- Warn that lab `006`'s two linking options are not interchangeable, because Option A creates the remote-peer Gateways without Helm ownership and lab `014`'s `peering-remote` upgrade then fails with `invalid ownership metadata`
- Use `MESH_NAME_CLUSTER*` rather than `KUBECONTEXT_CLUSTER*` for the `cluster` value in all four Solo UI labs, so the UI's telemetry correlates with the `source_cluster` Istio reports
- Note that the relay logs an IPv6 connect failure every few seconds on IPv4-only clusters, and give a ClickHouse query that confirms telemetry still arrives over IPv4
- Fix the access-control policies breaking once a waypoint is enrolled, by adding `auth-policy/waypoint-auth.yaml` to the three affected workshops, which keeps the pod-level rule for the waypoint and moves the identity rules to `targetRefs` policies where the original caller stays visible
- Repoint the dead `docs.solo.io/gloo-mesh` troubleshooting links in `000-tools.md` to the Solo Istio 1.31.x docs, and correct the stale namespace and context variables in both multicluster copies
- Rewrite `015-cleanup.md` to remove everything the workshop creates, guarding the custom-resource deletes behind a `kubectl get crd` check because `--ignore-not-found` still errors on a missing CRD
- Give `istio-ambient-multicluster-on-openshift/014-cleanup.md` the same coverage as its Kubernetes twin, including the `anyuid` SCC grants that outlive the namespaces
- Delete the ingress route and gateway before the namespaces in both single-cluster cleanup labs, where the route delete previously always found nothing
- Delete the orphaned `istio-ambient-multicluster-on-openshift/scc/` tree
- Stamp the cluster name into `reviews` in `istio-oss-sidecar-to-enterprise-ambient/002`, the one lab that deployed the backends without a following `set env`
- Stop hardcoding `CLUSTER_NAME: cluster1` in `bookinfo/bookinfo-backends.yaml`, so no cluster claims to be `cluster1` before lab `001` patches it
- Collapse the three sequential `set env deploy/reviews-v{1,2,3}` calls into one `set env deploy -l app=reviews`, cutting three rollouts to one per cluster
- Add the missing lab `005` dependency and a `No LoadBalancer?` fallback to `010-waypoints.md`
- Correct the `012-egress.md` ServiceEntry prose, which named a label the manifest never sets, and drop the empty `annotations:` key
- Correct the expected `x-envoy-decorator-operation` value in all five egress labs
- Make `kubectl create namespace` idempotent at 12 sites across all five workshops
- Normalize HTTPRoute from `gateway.networking.k8s.io/v1beta1` to `v1` at 6 sites
- Tell the reader to `cd` into the workshop directory, which every relative `kubectl apply -f bookinfo/...` depends on

0.1.8 - (7-23-26)
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