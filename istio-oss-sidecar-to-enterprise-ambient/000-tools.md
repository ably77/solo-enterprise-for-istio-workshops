# Tooling and Troubleshooting

## CLI Tools

### Solo's `istioctl` Binary

Used for debugging ambient mesh workloads (ztunnel, waypoints, proxy status):

```bash
ISTIO_VERSION=1.30.2
OS=$(uname | tr '[:upper:]' '[:lower:]' | sed -E 's/darwin/osx/')
ARCH=$(uname -m | sed -E 's/aarch/arm/; s/x86_64/amd64/; s/armv7l/armv7/')

INSTALL_DIR="."
mkdir -p "$INSTALL_DIR"
ISTIOCTL_URL="https://storage.googleapis.com/soloio-istio-binaries/release/${ISTIO_VERSION}-solo/istioctl-${ISTIO_VERSION}-solo-${OS}-${ARCH}.tar.gz"
curl -sSL "$ISTIOCTL_URL" | tar xzf - -C "$INSTALL_DIR"
mv "${INSTALL_DIR}/istioctl" "${INSTALL_DIR}/solo-istioctl"
chmod +x "${INSTALL_DIR}/solo-istioctl"
```

Useful commands:
```bash
# Get version info of binary AND cluster in current kubectl context
./solo-istioctl version

# Check proxy status (useful in Phase 1 with sidecars)
./solo-istioctl proxy-status

# Debug ztunnel workloads (useful after Phase 2 migration)
./solo-istioctl zc workloads -n istio-system --context $KUBECONTEXT_CLUSTER1

# Debug waypoints
./solo-istioctl waypoint

# Uninstall Istio when iterating
./solo-istioctl uninstall --purge -y --context $KUBECONTEXT_CLUSTER1
```

> **Note:** In Phase 1 (OSS Istio), you can also use the community `istioctl` binary for validation. `solo-istioctl` is a superset and works with both OSS and Solo Istio installs.

## Optional Tools

### K9s (CLI Kubernetes Control)

https://k9scli.io/ — powerful terminal UI for Kubernetes.

```bash
# Install (Mac/Linux)
brew install derailed/k9s/k9s

# Run
k9s
```

### Vegeta (CLI Load Generator)

https://github.com/tsenart/vegeta — simple command-line load generator.

```bash
# Install
brew install vegeta

# Run for 10 minutes, 1 request/sec, then report
echo "GET http://yourhostname/path" | vegeta attack -duration=600s -rate=1 | vegeta report --type=text
```

## Troubleshooting Resources

- Solo Istio Ambient debug: https://docs.solo.io/istio/1.31.x/troubleshooting/service-mesh/ambient/
- Solo Istio (general) debug: https://docs.solo.io/istio/1.31.x/troubleshooting/service-mesh/istio/
- OSS Ambient debugging: https://github.com/istio/istio/wiki/Troubleshooting-Istio-Ambient
