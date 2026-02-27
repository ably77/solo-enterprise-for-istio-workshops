# Prerequisites

1. A valid Solo.io license key (`$SOLO_TRIAL_LICENSE_KEY`)
2. `solo-istioctl` installed ([Solo istioctl installation](000-tools.md#solos-istioctl-binary))
3. `meshctl` installed ([meshctl installation](000-tools.md#meshctl-for-debugging-gme-related-resources))
4. `helm` installed
5. A Kubernetes cluster ≥ 1.29
6. `openssl` available in your shell — used in lab `004` to generate the shared root trust CA. macOS and Linux include this by default. Windows users must use WSL or Git Bash.
7. Optional: Vegeta for load generation ([Vegeta installation](000-tools.md#vegeta-cli-load-generator))

## Repos / Images

### Phase 1 — OSS Istio (Community Helm Charts)

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

helm pull istio/base --version 1.26.8
helm pull istio/istiod --version 1.26.8
helm pull istio/gateway --version 1.26.8
```

### Phase 2 — Solo Istio Helm Charts (OCI)

```bash
helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/base --version 1.29.0-solo
helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/istiod --version 1.29.0-solo
helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/cni --version 1.29.0-solo
helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/ztunnel --version 1.29.0-solo
```

### Solo Gloo Platform Helm Chart

```bash
helm pull gloo-platform \
  --version 2.12.0 \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts
```

### Solo Istio Images

```bash
docker pull us-docker.pkg.dev/soloio-img/istio/install-cni:1.29.0-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/pilot:1.29.0-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/proxyv2:1.29.0-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/ztunnel:1.29.0-solo-distroless
```

### OSS Istio Images

```bash
docker pull docker.io/istio/pilot:1.26.8
docker pull docker.io/istio/proxyv2:1.26.8
```

### Bookinfo Images

```bash
docker pull docker.io/istio/examples-bookinfo-details-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-ratings-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v2:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v3:1.20.2
docker pull docker.io/istio/examples-bookinfo-productpage-v1:1.20.2
```
