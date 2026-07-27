# Changelog

0.1.9 - (7-27-26)
---
- Update `.gitignore`
- Update Solo UI to `0.5.1`
- Add the `clickhouse.resources` override (500m CPU / 1Gi memory request) to `istio-ambient-single-cluster/009-install-solo-ui.md` and `istio-ambient-multicluster/013-install-solo-ui.md`. The chart defaults of 2 CPU and 3Gi leave the pod `Pending` on workshop-sized clusters, which crashloops `solo-enterprise-ui`. Both OpenShift labs already carried the override
- Warn that Segments break the Solo UI relay. Adds a blocking prerequisite, with a verification command, to `013-install-solo-ui.md` and `014-add-a-third-cluster.md`, and rewrites the `007-segments.md` cleanup heading so it reads as skippable only when you go straight to lab `008`. While a segment label sits on `istio-system`, Istio replaces the `*.mesh.internal` hostnames with the segment domain and the relay's `tunnel-client` restarts every two seconds on `lookup solo-enterprise-ui.kagent.mesh.internal ... no such host`
- Select the ztunnel pod on the same node as `productpage`, using `--field-selector spec.nodeName=` in place of `items[0]`, across all five observability labs. Each ztunnel reports metrics only for traffic on its own node, so the name-ordered pick returned nothing about half the time on multi-node clusters
- Replace stale Gloo Platform 2.12.0 references with Solo Management UI 0.5.1 across both multicluster workshops
- Remove the Gloo Platform 2.12.0 chart pull and version-table rows from `istio-oss-sidecar-to-enterprise-ambient`
- Rename the license prose to "Solo Trial License Key" across all five workshops
- Correct 12 inverted `region` values in the `peering` chart configs. Each entry under `remote.items[]` describes the remote peer, and Istio copies its `region` to that peer's `topology.kubernetes.io/region` label. Each entry carried the local cluster's region instead, so both clusters treated each other as same-region and locality-priority routing did not engage. Covers `006` in both multicluster workshops, `014`, and `advanced-scenarios/local-dev-against-global-mesh.md`, plus a callout in both `006` labs explaining the semantics
- Warn that lab `006`'s two linking options bind you. `solo-istioctl multicluster link` (Option A) creates the remote-peer Gateways with no Helm ownership metadata, so lab `014`'s `helm upgrade -i peering-remote` fails with `invalid ownership metadata`. `--take-ownership` fails too, on a field-manager conflict over `topology.kubernetes.io/region`. Lab `014` now documents the delete-the-Gateways-first remedy, and `006` points anyone planning to run `014` at Option B
- Replace the no-op `export SOLO_TRIAL_LICENSE_KEY=$SOLO_TRIAL_LICENSE_KEY` with a placeholder and a guard across all 9 install labs. The istiod chart accepts an empty license without complaint, so an unset variable produced a clean-looking install that failed later at peering
- Use `MESH_NAME_CLUSTER*` in place of `KUBECONTEXT_CLUSTER*` for the `cluster` value in all four Solo UI labs, and export the mesh names there. That value becomes the telemetry `cluster_name` attribute and the UI's `LOCAL_CLUSTER_NAME`, which have to match the `source_cluster` and `destination_cluster` Istio reports. On the KinD path the workshop documents, `kind-cluster1` against `cluster1`, they diverged and telemetry stopped correlating
- Fix the broken troubleshooting links in `000-tools.md` across three workshops. `https://docs.solo.io/gloo-mesh/latest/troubleshooting/debug/` 
- Delete the orphaned `istio-ambient-multicluster-on-openshift/scc/` tree
- Rewrite `015-cleanup.md` to remove everything the workshop creates. It missed the `egress` namespace from lab `012` and the `kagent` and `solo-enterprise` namespaces from lab `013`, and left the `management`, `relay` and `peering-remote` Helm releases in place. Adds Segment cleanup, `--ignore-not-found` throughout so skipped labs stay quiet, a verification step, an optional CRD removal block, and the two local files lab `002` writes. Guards the HTTPRoute, Gateway and Segment deletes behind a `kubectl get crd` check, because `--ignore-not-found` forgives a missing resource but still exits 1 on a missing CRD, which is what a second run hits after the CRD block removes them. The CRD block itself now matches `admin.solo.io`, so it takes `segments.admin.solo.io` with it
- Give `istio-ambient-multicluster-on-openshift` the same teardown as its Kubernetes twin. Lab `014-cleanup.md` uninstalled four Helm releases and deleted four namespaces, leaving Segments, the `management` and `relay` releases, the `peering-remote` release, and the `egress`, `kagent` and `solo-enterprise` namespaces behind. Also removes the `anyuid` SCC grants from labs `001` and `013`, which are cluster-scoped and outlive the namespaces
- Read ztunnel metrics from `kube-system` in `istio-ambient-multicluster-on-openshift/011-observability.md`. That workshop installs ztunnel and `istio-cni` into `kube-system`, so the pod lookup against `istio-system` returned an empty `ZTUNNEL_POD` and the port-forward that follows had nothing to bind
- Stamp the cluster name into `reviews` in `istio-oss-sidecar-to-enterprise-ambient/002-deploy-bookinfo-with-sidecars.md`. It was the one lab that deploys `bookinfo-backends.yaml` without a following `set env`, so the product page rendered "on cluster unset" for the rest of the workshop
- Note in lab `013` that the relay logs `dial tcp [2001:2::2]:4316: connect: network is unreachable` every couple of seconds on IPv4-only clusters. Istio allocates both an IPv4 and an IPv6 address per `*.mesh.internal` host and the collector tries IPv6 first; gRPC retries over IPv4 and telemetry arrives. The note gives a ClickHouse query to confirm data flow rather than reading the log
- Add the missing lab `005` dependency and a `No LoadBalancer?` fallback to `010-waypoints.md`, which claimed prereq `000-004` but read the productpage through `svc/ingress-istio`
- Correct the `012-egress.md` ServiceEntry prose, which named an `istio.io/use-waypoint-namespace` label the manifest never sets, and drop the empty `annotations:` key
- Make `kubectl create namespace` idempotent at 12 sites across all five workshops, using `--dry-run=client -o yaml | kubectl apply -f -`. Re-running a lab previously failed with `AlreadyExists`
- Normalize HTTPRoute from `gateway.networking.k8s.io/v1beta1` to `v1` at 6 sites. Gateway API v1.5.0 still serves `v1beta1`, so nothing was broken, but `010` already used `v1`
- Fix `000-tools.md` in both multicluster workshops
- Tell the reader to `cd` into the workshop directory. All five workshops run `kubectl apply -f bookinfo/...` and `./solo-istioctl` relative to it, and no README said so
- Collapse the three sequential `set env deploy/reviews-v{1,2,3}` calls in `001-deploy-bookinfo.md` into one `set env deploy -l app=reviews`, cutting three rollouts to one per cluster
- Stop hardcoding `CLUSTER_NAME: cluster1` in `bookinfo/bookinfo-backends.yaml`, now `unset`. Every cluster reported "cluster1" until lab `001` patched it, in the lab that teaches reading the cluster name off the page
- Derive `addressType` in the peering values from the e/w gateway address rather than hardcoding `IPAddress` with a comment telling the reader to edit it by hand

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