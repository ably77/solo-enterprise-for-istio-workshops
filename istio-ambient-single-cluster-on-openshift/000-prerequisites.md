# Prerequisites
1. A valid Solo.io license key
2. `solo-istioctl` installed — see [000-tools.md](000-tools.md#solos-istioctl-binary)
3. `helm` installed
4. `oc` (OpenShift CLI) installed
5. A Kubernetes/OpenShift version >= 1.29
6. (Optional) Vegeta for load generation — see [000-tools.md](000-tools.md#vegeta-cli-load-generator)

### Repos/Images

**Helm Repos**

Solo Istio Helm Charts
```bash
helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/base --version 1.29.0-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/istiod --version 1.29.0-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/cni --version 1.29.0-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/gateway --version 1.29.0-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/ztunnel --version 1.29.0-solo
```

**Istio Images:**
```bash
docker pull us-docker.pkg.dev/soloio-img/istio/install-cni:1.29.0-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/pilot:1.29.0-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/proxyv2:1.29.0-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/ztunnel:1.29.0-solo-distroless
```

**Bookinfo Images:**
```bash
docker pull docker.io/istio/examples-bookinfo-details-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-ratings-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v2:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v3:1.20.2
docker pull docker.io/istio/examples-bookinfo-productpage-v1:1.20.2
```
