# Prerequisites:
1. A valid Solo.io license key, exported as `$SOLO_TRIAL_LICENSE_KEY`
2. solo-istioctl installed ([Solo istioCTL installation](000-tools.md#solos-1250-istioctl-binary))
3. helm installed
4. A kubernetes version >1.29
5. `openssl` available in your shell — used in lab `002` to generate the shared root trust CA. macOS and Linux include this by default. Windows users must use WSL or Git Bash.
6. If you want to push local traffic easily install Vegeta as well ([Vegeta installation](000-tools.md#vegeta-cli-load-generator))

### Repos/Images:

**Helm Repos**

Solo Istio Helm Charts
```bash
helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/base --version 1.30.2-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/istiod --version 1.30.2-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/cni --version 1.30.2-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/gateway --version 1.30.2-solo

helm pull oci://us-docker.pkg.dev/soloio-img/istio-helm/ztunnel --version 1.30.2-solo
```

Solo Management UI Helm Charts (used in lab `013`)
```bash
helm pull oci://us-docker.pkg.dev/solo-public/solo-enterprise-helm/charts/management --version 0.5.1

helm pull oci://us-docker.pkg.dev/solo-public/solo-enterprise-helm/charts/relay --version 0.5.1
```

**Istio Images:** 
```bash
docker pull us-docker.pkg.dev/soloio-img/istio/install-cni:1.30.2-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/pilot:1.30.2-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/proxyv2:1.30.2-solo-distroless
docker pull us-docker.pkg.dev/soloio-img/istio/ztunnel:1.30.2-solo-distroless
```

**Book Info Images:**
```bash
docker pull docker.io/istio/examples-bookinfo-details-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-ratings-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v1:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v2:1.20.2
docker pull docker.io/istio/examples-bookinfo-reviews-v3:1.20.2
```

**Solo Management UI Images (Optional, we can upload later for phase 2 of POC)**

Management cluster (`management` chart, lab `013`):
```bash
docker pull us-docker.pkg.dev/solo-public/solo-enterprise/solo-enterprise-ui-frontend:0.5.1
docker pull us-docker.pkg.dev/solo-public/solo-enterprise/solo-enterprise-ui-backend:0.5.1
docker pull us-docker.pkg.dev/solo-public/solo-enterprise/solo-enterprise-tunnel-server:0.5.1
docker pull us-docker.pkg.dev/solo-public/solo-enterprise/solo-enterprise-autoauth:v0.2.2
docker pull clickhouse/clickhouse-server:26.3.17-alpine
docker pull docker.io/otel/opentelemetry-collector-contrib:0.153.0
```

Workload clusters (`relay` chart, lab `013`):
```bash
docker pull us-docker.pkg.dev/solo-public/solo-enterprise/solo-enterprise-tunnel-client:0.5.1
docker pull docker.io/otel/opentelemetry-collector-contrib:0.153.0
```

> **Note:** Lab `013` includes commented-out `image` override blocks in both Helm values files. Uncomment
> them and point them at your private registry when you run from mirrored images.

