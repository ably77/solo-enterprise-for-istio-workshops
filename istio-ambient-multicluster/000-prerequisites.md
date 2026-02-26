# Prerequisites:
1. A valid license key
2. solo-istioctl installed ([Solo istioCTL installation](000-tools.md#solos-1250-istioctl-binary))
3. meshctl install ([meshctl installation](000-tools.md#meshctl-for-debugging-gme-related-resources))
4. helm installed
5. A kubernetes version >1.29
6. `openssl` available in your shell — used in lab `002` to generate the shared root trust CA. macOS and Linux include this by default. Windows users must use WSL or Git Bash.
7. If you want to push local traffic easily install Vegeta as well ([Vegeta installation](000-tools.md#vegeta-cli-load-generator))

### Repos/Images:

**Helm Repos**

Solo Istio Helm Charts
```bash
helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/base --version 1.29.0-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/istiod --version 1.29.0-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/cni --version 1.29.0-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/gateway --version 1.29.0-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/ztunnel --version 1.29.0-solo
```

Solo Gloo Mesh Enterprise Helm Chart
```bash
helm pull gloo-platform \
  --version 2.12.0 \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts
```

**Istio Images:** 
```bash
docker pull us-docker.pkg.dev/soloio-img/istio/install-cni:1.29.0-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/pilot:1.29.0-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/proxyv2:1.29.0-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/ztunnel:1.29.0-solo-distroless
```

**Book Info Images:**
```bash
docker pull docker.io/istio/examples-bookinfo-details-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-ratings-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v2:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v3:1.20.2
```

**GME Images (Optional, we can upload later for phase 2 of POC)**
```bash
docker pull gcr.io/gloo-mesh/gloo-mesh-agent:2.12.0
docker pull gcr.io/gloo-mesh/gloo-mesh-apiserver:2.12.0
docker pull gcr.io/gloo-mesh/gloo-mesh-envoy:2.12.0
docker pull gcr.io/gloo-mesh/gloo-mesh-mgmt-server:2.12.0
docker pull gcr.io/gloo-mesh/gloo-mesh-ui:2.12.0
docker pull gcr.io/gloo-mesh/otel-collector:0.2.3
docker pull gcr.io/gloo-mesh/prometheus:v2.53.4
docker pull gcr.io/gloo-mesh/redis:7.4.2-alpine
docker pull quay.io/prometheus-operator/prometheus-config-reloader:v0.74.0
```

