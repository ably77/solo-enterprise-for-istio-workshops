# TOOLING AND TROUBLESHOOTING

## CLI Tools useful for debugging

#### Solo's `istioctl` Binary
```bash
ISTIO_VERSION=1.29.0
OS=$(uname | tr '[:upper:]' '[:lower:]' | sed -E 's/darwin/osx/')
ARCH=$(uname -m | sed -E 's/aarch/arm/; s/x86_64/amd64/; s/armv7l/armv7/')

INSTALL_DIR="."
mkdir -p "$INSTALL_DIR"
curl -sSL https://storage.googleapis.com/soloio-istio-binaries/release/${ISTIO_VERSION}-solo/istioctl-${ISTIO_VERSION}-solo-${OS}-${ARCH}.tar.gz | tar xzf - -C "$INSTALL_DIR"
mv "${INSTALL_DIR}/istioctl" "${INSTALL_DIR}/solo-istioctl"
chmod +x "${INSTALL_DIR}/solo-istioctl"
```

Useful commands:
```bash
# Get version info of binary AND cluster in current kubectl context
./solo-istioctl version

# Useful for removing Istio when iterating version / testing
./solo-istioctl uninstall --purge -y

# Debug istio proxy status
./solo-istioctl proxy-status

# Debug ZTunnel
./solo-istioctl zc

# Debug Waypoints
./solo-istioctl waypoint
```

## Optional Tools

#### K9s (CLI K8s control)
https://k9scli.io/

On Mac/Linux:
```bash
brew install derailed/k9s/k9s
k9s
```

#### Vegeta (CLI load generator)
https://github.com/tsenart/vegeta

On Mac/Linux:
```bash
brew install vegeta

# Run for 10 minutes, 1 query per second, then report
echo "GET http://yourhostname/path" | vegeta attack -duration=600s -rate=1 | vegeta report --type=text
```

#### Fortio (load generator)
https://github.com/fortio/fortio

On Mac/Linux:
```bash
brew install fortio
```

## Troubleshooting Resources

OSS Ambient debugging information:
https://github.com/istio/istio/wiki/Troubleshooting-Istio-Ambient
