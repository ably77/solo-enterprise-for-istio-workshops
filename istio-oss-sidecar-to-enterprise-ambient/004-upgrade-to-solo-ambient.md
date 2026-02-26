# Upgrade to Solo Enterprise Istio Ambient

# Objectives
- Download `solo-istioctl` for Phase 2 operations
- Upgrade `istio-cni` to Solo ambient-capable version
- Upgrade `istiod` from OSS community to Solo Enterprise
- Install `ztunnel` (new ambient data plane component)
- Observe that existing sidecar workloads continue running during the upgrade

![](../images/upgrade-to-solo-ambient-1.png)

## Prerequisites
- This lab assumes you have completed labs `001`–`003`
- Bookinfo is deployed with sidecars (pods show `2/2 READY`)

## Set Environment Variables

```bash
export CLUSTER1=cluster1
export SOLO_TRIAL_LICENSE_KEY=$SOLO_TRIAL_LICENSE_KEY
export ISTIO_VERSION=1.29.0
```

## Download `solo-istioctl`

```bash
OS=$(uname | tr '[:upper:]' '[:lower:]' | sed -E 's/darwin/osx/')
ARCH=$(uname -m | sed -E 's/aarch/arm/; s/x86_64/amd64/; s/armv7l/armv7/')

INSTALL_DIR="."
mkdir -p "$INSTALL_DIR"
curl -sSL https://storage.googleapis.com/soloio-istio-binaries/release/${ISTIO_VERSION}-solo/istioctl-${ISTIO_VERSION}-solo-${OS}-${ARCH}.tar.gz | tar xzf - -C "$INSTALL_DIR"
mv "${INSTALL_DIR}/istioctl" "${INSTALL_DIR}/solo-istioctl"
chmod +x "${INSTALL_DIR}/solo-istioctl"
```

Verify:
```bash
./solo-istioctl version
```

## Install Solo `istio-cni` (Ambient CNI Plugin)

Install the Solo Istio CNI component with the ambient profile. This replaces the OSS CNI and adds the ambient traffic interception capabilities needed by ztunnel:

> **GKE only:** Uncomment `platform: gke` under `global` in the values below before running this command. Also run the GKE resource quota patch first:
> ```bash
> kubectl apply -f gke/resourcequota.yaml --context $CLUSTER1
> ```

```bash
helm upgrade --kube-context $CLUSTER1 --install istio-cni oci://us-docker.pkg.dev/soloio-img/istio-helm/cni \
-n istio-system \
--version=$ISTIO_VERSION-solo \
-f -<<EOF
profile: ambient
ambient:
  dnsCapture: true
excludeNamespaces:
  - istio-system
  - kube-system
global:
  # uncomment if using GKE
  #platform: gke
  hub: us-docker.pkg.dev/soloio-img/istio
  tag: $ISTIO_VERSION-solo
  variant: distroless
EOF
```

Wait for the CNI DaemonSet to roll out on all nodes:
```bash
kubectl rollout status ds/istio-cni-node -n istio-system --watch --timeout=90s --context $CLUSTER1
```

## Upgrade `istiod` to Solo Enterprise Ambient

Before upgrading, delete the `ValidatingWebhookConfiguration` left by the OSS istiod. When upgrading between different istiod releases (different Helm chart publishers), the existing resource has a `pilot-discovery` field manager that conflicts with the Solo chart's server-side apply. Deleting it is safe — Solo istiod recreates it on install:

```bash
kubectl delete validatingwebhookconfiguration istio-validator-istio-system --context $CLUSTER1 --ignore-not-found
```

Upgrade istiod from the community chart to the Solo OCI chart with ambient profile enabled. The `--install` flag makes this an upgrade-or-install operation.

The Solo istiod will pick up the existing `istio-ca-secret` that OSS istiod auto-generated, keeping the same `cluster.local` trust domain and CA root throughout the migration. No certificate rotation is needed — existing sidecar workload certs remain valid during the coexistence period:

```bash
helm upgrade --kube-context $CLUSTER1 --install istiod oci://us-docker.pkg.dev/soloio-img/istio-helm/istiod \
-n istio-system \
--version=$ISTIO_VERSION-solo \
-f -<<EOF
profile: ambient
global:
  hub: us-docker.pkg.dev/soloio-img/istio
  tag: $ISTIO_VERSION-solo
  variant: distroless
license:
  value: $SOLO_TRIAL_LICENSE_KEY
EOF
```

Wait for istiod to roll out:
```bash
kubectl rollout status deploy/istiod -n istio-system --watch --timeout=90s --context $CLUSTER1
```

## Install `ztunnel`

ztunnel is the ambient data plane component — a lightweight L4 proxy that runs as a DaemonSet on every node. It handles mTLS transparently for all workloads in ambient-enrolled namespaces. This component does not exist in a standard OSS Istio install:

```bash
helm upgrade --kube-context $CLUSTER1 --install ztunnel oci://us-docker.pkg.dev/soloio-img/istio-helm/ztunnel \
-n istio-system \
--version=$ISTIO_VERSION-solo \
-f -<<EOF
profile: ambient
proxy:
  clusterDomain: cluster.local
logLevel: info
global:
  hub: us-docker.pkg.dev/soloio-img/istio
  tag: $ISTIO_VERSION-solo
  variant: distroless
terminationGracePeriodSeconds: 30
resources:
  requests:
    cpu: 500m
    memory: 2048Mi
istioNamespace: istio-system
env:
  L7_ENABLED: "true"
EOF
```

Wait for ztunnel to roll out across all nodes:
```bash
kubectl rollout status ds/ztunnel -n istio-system --watch --timeout=90s --context $CLUSTER1
```

## Validate the Migration

Check the control plane components:
```bash
kubectl get pods -n istio-system --context $CLUSTER1
```

You should now see all three ambient components running alongside the upgraded istiod:
```
NAME                      READY   STATUS    RESTARTS   AGE
istio-cni-node-<hash>     1/1     Running   0          2m    # ambient CNI, one per node
istiod-<hash>             1/1     Running   0          1m    # Solo Enterprise control plane
ztunnel-<hash>            1/1     Running   0          30s   # ambient L4 proxy, one per node
```

**Key observation — coexistence period:** Check that the existing Bookinfo pods still have their sidecars. Both models operate simultaneously at this point — the migration is non-disruptive:

```bash
kubectl get pods -n bookinfo-frontends --context $CLUSTER1
kubectl get pods -n bookinfo-backends --context $CLUSTER1
```

Expected output — pods still show `2/2 READY` (sidecar still attached):
```
NAME                             READY   STATUS    RESTARTS   AGE
productpage-v1-<hash>            2/2     Running   0          15m
```

The application is running and serving traffic through the upgraded control plane. Existing sidecar workloads are unaffected. In the next lab we will migrate the namespaces to ambient mode.

## Next Steps

At this point we have completed the following objectives:
- Downloaded `solo-istioctl`
- Installed Solo `istio-cni` with ambient profile
- Upgraded `istiod` to Solo Enterprise (reusing existing `istio-ca-secret` and `cluster.local` trust domain)
- Installed `ztunnel` DaemonSet
- Confirmed sidecar workloads continue running (coexistence period)

In the next step `005` we will migrate the bookinfo namespaces from sidecar mode to ambient mode
