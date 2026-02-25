# TOOLING AND TROUBLESHOOTING
## CLI Tools useful for debugging

#### Solo's `istioctl` Binary:
```bash
ISTIO_VERSION=1.28.3
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
#get version info of binary AND cluster in current kubectl context
./solo-istioctl version

#useful for removing Istio when iterating version / testing
./solo-istioctl uninstall --purge -y --context $context 

#create a quick east-west gateway for multicluster peering
./solo-istioctl multicluster expose --namespace istio-eastwest --context ${context}

#generates a multicluster link between two clusters
./solo-istioctl multicluster link --namespace istio-eastwest --contexts=${REMOTE_CONTEXT1},${REMOTE_CONTEXT2} 

#debug istio proxy status
./solo-istioctl proxy-status

#debug ZTunnel
./solo-istioctl zc 

#debug Waypoints
./solo-istioctl waypoint
```

#### MeshCTL for debugging GME related resources:

```bash
curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v2.8.0 sh -
export PATH=$HOME/.gloo-mesh/bin:$PATH
```

Useful Commands:
```bash
#check License Key
meshctl license check

#check environment before GME install
meshctl precheck

#check status of Gloo Mesh Server / Agent
meshctl check

#generate debug report 
meshctl debug report

#launch dashboard (can portforward 8090 on the ui pod as well)
meshctl dashboard
```

### Configure Trust  and Namespaces- Issue Intermediate Certs
```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh 
cd istio-${ISTIO_VERSION}
mkdir -p certs
pushd certs
make -f ../tools/certs/Makefile.selfsigned.mk root-ca

function create_cacerts_secret() {
  context=${1:?context}
  cluster=${2:?cluster}
  make -f ../tools/certs/Makefile.selfsigned.mk ${cluster}-cacerts
  kubectl --context=${context} create ns istio-system || true
  kubectl --context=${context} create secret generic cacerts -n istio-system \
    --from-file=${cluster}/ca-cert.pem \
    --from-file=${cluster}/ca-key.pem \
    --from-file=${cluster}/root-cert.pem \
    --from-file=${cluster}/cert-chain.pem
}

create_cacerts_secret ${CLUSTER1} cluster1
create_cacerts_secret ${CLUSTER2} cluster2
cd ../../
```

## Optional Tools
#### K9s (CLI K8s control)
https://k9scli.io/ Takes a bit to get used, but is very powerful.
On Mac / Linux:
```bash
 #install 
 brew install derailed/k9s/k9s
 #run
 k9s
```

On Mac/Linux:
#### Vegeta (CLI load generator)
https://github.com/tsenart/vegeta Very easy to use command line load generator with a command line output result
On Mac/Linux:
```bash
#install
brew install vegeta

#run for 10 minutes, 1 query per second then report
echo "GET http://yourhostname/path" | vegeta attack -duration=600s -rate=1 | vegeta report --type=text
```
#### Fortio (load generator)
https://github.com/fortio/fortio Fortio has a lot of features for load testing and reporting, and can be run in a k8s pod. This is for more feature complete stress testing, for more quick and dirty results use Vegeta
On Mac/Linux:
```bash
brew install fortio
```
## Troubleshooting Resources:
GME / Ambient debug information (check here first)
https://docs.solo.io/gloo-mesh/latest/troubleshooting/debug/

OSS Ambient Debugging information
https://github.com/istio/istio/wiki/Troubleshooting-Istio-Ambient