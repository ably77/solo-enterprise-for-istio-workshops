# Changelog

0.1.4 - (4-8-26)
---
- Fix undefined `$CLUSTER1`/`$CLUSTER2` in `topology.istio.io/network` label commands — replace with `$MESH_NAME_CLUSTER1`/`$MESH_NAME_CLUSTER2` across all install docs
- Add KinD callout to all install docs warning that `KUBECONTEXT_CLUSTER*` should include the `kind-` prefix but `MESH_NAME_CLUSTER*` should not
- Refactor `solo-istioctl` download to extract URL into `$ISTIOCTL_URL` variable across all workshops
- Add port-forward fallback section to expose-bookinfo labs in multicluster-on-openshift, single-cluster, and single-cluster-on-openshift workshops
- Add Colima to list of platforms without LoadBalancer support in expose-bookinfo notes

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