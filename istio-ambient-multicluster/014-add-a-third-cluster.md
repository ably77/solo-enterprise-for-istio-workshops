# Bonus: Add a Third Cluster

# Objectives
- Install Istio Ambient on a third cluster (`cluster3`), reusing the shared root of trust from lab `002`
- Deploy Bookinfo on `cluster3` and enroll it in the ambient mesh
- Extend cluster peering from a pair into a full mesh across all three clusters
- Extend the global `productpage` service to `cluster3` and observe three-way failover

## Prerequisites
- This lab assumes you have completed setup from labs `000`-`006` at minimum: `cluster1` and `cluster2` are linked, Bookinfo is deployed on both, and `productpage` is already configured as a global service. Labs `007`-`013` are not required to continue.
- A third Kubernetes cluster (≥ 1.29), reachable via its own kubectl context
- `shared-root-trust-secret.yaml`, generated in lab `002`, still present in this directory

> **Run the cleanup in lab `007` or `008` before starting this lab.** Segments replace the
> `*.mesh.internal` hostnames with the segment domain, and this lab routes to
> `productpage.bookinfo-frontends.mesh.internal`. Verify that no segment label remains on `istio-system`
> in either existing cluster:
>
> ```bash
> kubectl get ns istio-system --context $KUBECONTEXT_CLUSTER1 -o jsonpath='{.metadata.labels.admin\.solo\.io/segment}{"\n"}'
> kubectl get ns istio-system --context $KUBECONTEXT_CLUSTER2 -o jsonpath='{.metadata.labels.admin\.solo\.io/segment}{"\n"}'
> ```
>
> Both should print an empty line.

## Set cluster contexts
In this workshop, you can use your preferred cluster context. To set it, run the following command, replacing cluster3 with your desired context name
```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name
export KUBECONTEXT_CLUSTER2=cluster2  # Replace with your actual kubectl context name

export KUBECONTEXT_CLUSTER3=cluster3  # Replace with your actual kubectl context name
export MESH_NAME_CLUSTER3=cluster3    # Recommended to keep as cluster3 for POC
```

> **KinD users:** KinD automatically prefixes kubecontext names with `kind-`. You can set `KUBECONTEXT_CLUSTER3=kind-<cluster-name>` but keep `MESH_NAME_CLUSTER3=<cluster-name>` (without the `kind-` prefix). The `MESH_NAME_CLUSTER3` value is the Istio network name — it must match the `topology.istio.io/network` label on the `istio-system` namespace and the ztunnel `NETWORK` env var. Mismatching these causes ztunnel to fail VIP lookups, silently bypassing waypoints.

And re-export your Solo Trial License Key and Istio version, if they are no longer set in your shell
```bash
export SOLO_TRIAL_LICENSE_KEY=<paste-your-key>
[ -n "$SOLO_TRIAL_LICENSE_KEY" ] || echo "⚠️  SOLO_TRIAL_LICENSE_KEY is not set. Istio installs with an empty license and enterprise features, including multicluster peering, then fail."
export ISTIO_VERSION=1.30.2
```

## Merge cluster3's kubeconfig into your existing config

`cluster3` commonly comes from a separate kubeconfig file than the one already holding `cluster1`/`cluster2` (e.g. a new cloud project or a freshly downloaded cluster credential). Every command in this lab switches contexts with `--context`, so all three must be visible from the same `KUBECONFIG`. Check what's currently loaded:
```bash
kubectl config get-contexts
```

If `$KUBECONTEXT_CLUSTER3` isn't listed, flatten it together with your existing config into one file and point `KUBECONFIG` at the result:
```bash
KUBECONFIG=~/.kube/config:/path/to/cluster3-kubeconfig.yaml kubectl config view --flatten > /tmp/merged-kubeconfig.yaml
export KUBECONFIG=/tmp/merged-kubeconfig.yaml
```

Confirm all three contexts now resolve
```bash
kubectl config get-contexts
```

> If you already merged multiple kubeconfig files back in lab `006`, just fold cluster3's file into that same merge instead of starting from `~/.kube/config`.

## Create istio-system namespace and apply shared root trust secret on cluster3

All three clusters must share the same root of trust so workloads can verify each other's mTLS certificates across cluster boundaries. `cluster3` reuses the exact same `shared-root-trust-secret.yaml` generated back in lab `002`. Do not regenerate it.
```bash
kubectl create namespace istio-system --context $KUBECONTEXT_CLUSTER3 --dry-run=client -o yaml | kubectl apply --context $KUBECONTEXT_CLUSTER3 -f -
kubectl apply -f shared-root-trust-secret.yaml --context $KUBECONTEXT_CLUSTER3
```

## Install Istio using Helm on cluster3

Install istio-base
```bash
helm upgrade --kube-context $KUBECONTEXT_CLUSTER3 --install istio-base oci://us-docker.pkg.dev/soloio-img/istio-helm/base -n istio-system --version $ISTIO_VERSION-solo --create-namespace

kubectl label namespace istio-system topology.istio.io/network=$MESH_NAME_CLUSTER3 --context $KUBECONTEXT_CLUSTER3
```

Install Kubernetes Gateway CRDs if not already present

**NOTE:** The command below is idempotent — it checks whether the CRDs exist before applying them and is safe to run on any Kubernetes distribution.
```bash
kubectl get crd gateways.gateway.networking.k8s.io --context $KUBECONTEXT_CLUSTER3 &> /dev/null || \
  { kubectl --context $KUBECONTEXT_CLUSTER3 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml; }
```

> **GKE only:** Any pods with the `system-node-critical` priorityClassName can only be installed in namespaces that have a ResourceQuota defined. By default in GKE, only `kube-system` has a defined ResourceQuota for the node-critical class. Run the following to allow `istio-cni` to be deployed in the `istio-system` namespace:
> ```bash
> kubectl apply -f gke/resourcequota.yaml --context $KUBECONTEXT_CLUSTER3
> ```

Install istio-cni

> **GKE users:** Uncomment `platform: gke` under `global` in the values below before running this command.

```bash
helm upgrade --kube-context $KUBECONTEXT_CLUSTER3 --install istio-cni oci://us-docker.pkg.dev/soloio-img/istio-helm/cni \
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

Wait for rollout to complete
```bash
kubectl rollout status ds/istio-cni-node -n istio-system --watch --timeout=90s --context $KUBECONTEXT_CLUSTER3
```

Install istiod
```bash
helm upgrade --kube-context $KUBECONTEXT_CLUSTER3 --install istiod oci://us-docker.pkg.dev/soloio-img/istio-helm/istiod \
-n istio-system \
--version=$ISTIO_VERSION-solo \
-f -<<EOF
profile: ambient
global:
  hub: us-docker.pkg.dev/soloio-img/istio
  tag: $ISTIO_VERSION-solo
  variant: distroless
  multiCluster:
    clusterName: $MESH_NAME_CLUSTER3
  network: $MESH_NAME_CLUSTER3
meshConfig:
  trustDomain: $MESH_NAME_CLUSTER3.local
env:
  # Enables assigning multi-cluster services an IP address
  PILOT_ENABLE_IP_AUTOALLOCATE: "true"
  # Disable selecting workload entries for local service routing.
  # Required for Solo Istio multicluster functionality.
  PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
  # Required if you have distinct trust domains per-cluster
  PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
  # Enables experimental Gateway API features to be used
  #PILOT_ENABLE_ALPHA_GATEWAY_API: "true"
# Required to enable multi-cluster support
platforms:
  peering:
    enabled: true
license:
  value: $SOLO_TRIAL_LICENSE_KEY
EOF
```

Wait for rollout to complete
```bash
kubectl rollout status deploy/istiod -n istio-system --watch --timeout=90s --context $KUBECONTEXT_CLUSTER3
```

Install ztunnel
```bash
helm upgrade --kube-context $KUBECONTEXT_CLUSTER3 --install ztunnel oci://us-docker.pkg.dev/soloio-img/istio-helm/ztunnel \
-n istio-system \
--version=$ISTIO_VERSION-solo \
-f -<<EOF
profile: ambient
logLevel: info
global:
  hub: us-docker.pkg.dev/soloio-img/istio
  tag: $ISTIO_VERSION-solo
  variant: distroless
resources:
  requests:
      cpu: 500m
      memory: 2048Mi
istioNamespace: istio-system
env:
  L7_ENABLED: "true"
  # Required if you have distinct trust domains per-cluster
  SKIP_VALIDATE_TRUST_DOMAIN: "true"
# Must match the setting during Istio installation
network: $MESH_NAME_CLUSTER3
multiCluster:
  clusterName: $MESH_NAME_CLUSTER3
EOF
```

Wait for rollout to complete
```bash
kubectl rollout status ds/ztunnel -n istio-system --watch --timeout=90s --context $KUBECONTEXT_CLUSTER3
```

## Deploy Bookinfo on cluster3

Deploy bookinfo frontends and backends
```bash
kubectl apply -f bookinfo/bookinfo-frontends.yaml --context $KUBECONTEXT_CLUSTER3
kubectl apply -f bookinfo/bookinfo-backends.yaml --context $KUBECONTEXT_CLUSTER3
```

Wait for the applications to be deployed
```bash
for deploy in $(kubectl get deploy -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER3 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Waiting for frontend deployment '$deploy' to be ready in $KUBECONTEXT_CLUSTER3..."
  kubectl rollout status deploy/"$deploy" -n bookinfo-frontends --watch --timeout=90s --context $KUBECONTEXT_CLUSTER3
  done

for deploy in $(kubectl get deploy -n bookinfo-backends --context $KUBECONTEXT_CLUSTER3 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Waiting for backend deployment '$deploy' to be ready in $KUBECONTEXT_CLUSTER3..."
  kubectl rollout status deploy/"$deploy" -n bookinfo-backends --watch --timeout=90s --context $KUBECONTEXT_CLUSTER3
  done
```

Update the reviews service to display which cluster it is coming from
```bash
kubectl --context $KUBECONTEXT_CLUSTER3 -n bookinfo-backends set env deploy -l app=reviews CLUSTER_NAME=$MESH_NAME_CLUSTER3
```

## Enroll Apps to Ambient Mesh on cluster3

Enable ambient with a namespace label — no sidecar injection, no pod restarts required
```bash
kubectl label namespace bookinfo-frontends istio.io/dataplane-mode=ambient --context $KUBECONTEXT_CLUSTER3
kubectl label namespace bookinfo-backends istio.io/dataplane-mode=ambient --context $KUBECONTEXT_CLUSTER3
```

Confirm the workloads are enrolled — the protocol should show `HBONE`
```bash
./solo-istioctl zc workloads -n istio-system --context $KUBECONTEXT_CLUSTER3 | grep "bookinfo"
```

`cluster3` does not need its own ingress gateway. Like `cluster2`, it will only serve traffic as a failover target reached through `cluster1`'s ingress.

## Extend peering into a full mesh

So far `cluster1` and `cluster2` are linked as a pair. Adding `cluster3` means every cluster needs a direct peering relationship with every other cluster — a full mesh, not a hub-and-spoke.

Create the `istio-gateways` namespace and expose an e/w gateway on cluster3
```bash
kubectl create ns istio-gateways --context $KUBECONTEXT_CLUSTER3 --dry-run=client -o yaml | kubectl apply --context $KUBECONTEXT_CLUSTER3 -f -

./solo-istioctl multicluster expose --namespace istio-gateways --context $KUBECONTEXT_CLUSTER3
```

Wait for the e/w gateway to be deployed
```bash
for deploy in $(kubectl get deploy -n istio-gateways --context $KUBECONTEXT_CLUSTER3 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Waiting for e/w gateway deployment '$deploy' to be ready in $KUBECONTEXT_CLUSTER3..."
  kubectl rollout status deploy/"$deploy" -n istio-gateways --watch --timeout=90s --context $KUBECONTEXT_CLUSTER3
  done
```

> **Note:** The cloud load balancer for the e/w gateway may take a few minutes to be provisioned. If `EXTERNAL-IP` shows `<pending>`, wait and re-run `kubectl get svc -n istio-gateways --context $KUBECONTEXT_CLUSTER3` until an address is assigned before proceeding to link it.

You can link the clusters with either the Solo `istioctl` CLI or the `peering` Helm chart. Both produce the same result — pick the option matching what you used in lab `006`.

#### Option A: solo-istioctl

Re-run the link command with all three contexts. It is idempotent and will fill in the missing `cluster1<->cluster3` and `cluster2<->cluster3` links without disturbing the existing `cluster1<->cluster2` link.
```bash
./solo-istioctl multicluster link --contexts=$KUBECONTEXT_CLUSTER1,$KUBECONTEXT_CLUSTER2,$KUBECONTEXT_CLUSTER3 --namespace istio-gateways
```

#### Option B: Helm (`peering` chart)

Export the Istio version and each cluster's network name — these should match the `MESH_NAME_CLUSTER*` values used to install Istio in labs `002`/`003` and above.
```bash
export ISTIO_VERSION=1.30.2
export MESH_NAME_CLUSTER1=cluster1
export MESH_NAME_CLUSTER2=cluster2
export MESH_NAME_CLUSTER3=cluster3
```

Get the e/w gateway address in each cluster
```bash
export CLUSTER1_EW_ADDRESS=$(kubectl get svc -n istio-gateways istio-eastwest --context $KUBECONTEXT_CLUSTER1 -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
export CLUSTER2_EW_ADDRESS=$(kubectl get svc -n istio-gateways istio-eastwest --context $KUBECONTEXT_CLUSTER2 -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
export CLUSTER3_EW_ADDRESS=$(kubectl get svc -n istio-gateways istio-eastwest --context $KUBECONTEXT_CLUSTER3 -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")

# Peering needs to know whether each address is an IP or a DNS name
export CLUSTER1_EW_ADDRESS_TYPE=$([[ $CLUSTER1_EW_ADDRESS =~ ^[0-9.]+$ ]] && echo IPAddress || echo Hostname)
export CLUSTER2_EW_ADDRESS_TYPE=$([[ $CLUSTER2_EW_ADDRESS =~ ^[0-9.]+$ ]] && echo IPAddress || echo Hostname)
export CLUSTER3_EW_ADDRESS_TYPE=$([[ $CLUSTER3_EW_ADDRESS =~ ^[0-9.]+$ ]] && echo IPAddress || echo Hostname)

echo "Cluster1 e/w gateway: $CLUSTER1_EW_ADDRESS ($CLUSTER1_EW_ADDRESS_TYPE)"
echo "Cluster2 e/w gateway: $CLUSTER2_EW_ADDRESS ($CLUSTER2_EW_ADDRESS_TYPE)"
echo "Cluster3 e/w gateway: $CLUSTER3_EW_ADDRESS ($CLUSTER3_EW_ADDRESS_TYPE)"
```

> **If you linked with Option A (`solo-istioctl multicluster link`) in lab `006`, delete those Gateways first.** `istioctl` created them without a Helm release behind them, so the `helm upgrade -i` commands below fail with:
>
> ```
> Error: unable to continue with install: Gateway "istio-remote-peer-cluster2" in namespace
> "istio-gateways" exists and cannot be imported into the current release: invalid ownership metadata
> ```
>
> `--take-ownership` fails too, on a field-manager conflict over
> `.metadata.labels.topology.kubernetes.io/region`. Delete the two Gateways, then run the Helm commands
> below. Peering re-establishes as soon as Helm applies the release:
>
> ```bash
> kubectl delete gateway istio-remote-peer-$MESH_NAME_CLUSTER2 -n istio-gateways --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
> kubectl delete gateway istio-remote-peer-$MESH_NAME_CLUSTER1 -n istio-gateways --context $KUBECONTEXT_CLUSTER2 --ignore-not-found
> ```

The `peering-remote` release's `remote.items` list is a full replacement on every `helm upgrade`, not additive — so each cluster's release must list *every other* cluster as a remote peer. Re-apply `cluster1` and `cluster2` with `cluster3` added to their items list, and install a new release on `cluster3` listing both `cluster1` and `cluster2`:
```bash
helm upgrade -i peering-remote oci://us-docker.pkg.dev/soloio-img/istio-helm/peering \
  --version $ISTIO_VERSION-solo \
  --namespace istio-gateways \
  --kube-context $KUBECONTEXT_CLUSTER1 \
  -f - <<EOF
remote:
  create: true
  items:
    - name: istio-remote-peer-$MESH_NAME_CLUSTER2
      cluster: $MESH_NAME_CLUSTER2
      network: $MESH_NAME_CLUSTER2
      addressType: $CLUSTER2_EW_ADDRESS_TYPE
      address: $CLUSTER2_EW_ADDRESS
      preferredDataplaneServiceType: loadbalancer
      trustDomain: $MESH_NAME_CLUSTER2.local
      region: region2
    - name: istio-remote-peer-$MESH_NAME_CLUSTER3
      cluster: $MESH_NAME_CLUSTER3
      network: $MESH_NAME_CLUSTER3
      addressType: $CLUSTER3_EW_ADDRESS_TYPE
      address: $CLUSTER3_EW_ADDRESS
      preferredDataplaneServiceType: loadbalancer
      trustDomain: $MESH_NAME_CLUSTER3.local
      region: region3
EOF

helm upgrade -i peering-remote oci://us-docker.pkg.dev/soloio-img/istio-helm/peering \
  --version $ISTIO_VERSION-solo \
  --namespace istio-gateways \
  --kube-context $KUBECONTEXT_CLUSTER2 \
  -f - <<EOF
remote:
  create: true
  items:
    - name: istio-remote-peer-$MESH_NAME_CLUSTER1
      cluster: $MESH_NAME_CLUSTER1
      network: $MESH_NAME_CLUSTER1
      addressType: $CLUSTER1_EW_ADDRESS_TYPE
      address: $CLUSTER1_EW_ADDRESS
      preferredDataplaneServiceType: loadbalancer
      trustDomain: $MESH_NAME_CLUSTER1.local
      region: region1
    - name: istio-remote-peer-$MESH_NAME_CLUSTER3
      cluster: $MESH_NAME_CLUSTER3
      network: $MESH_NAME_CLUSTER3
      addressType: $CLUSTER3_EW_ADDRESS_TYPE
      address: $CLUSTER3_EW_ADDRESS
      preferredDataplaneServiceType: loadbalancer
      trustDomain: $MESH_NAME_CLUSTER3.local
      region: region3
EOF

helm upgrade -i peering-remote oci://us-docker.pkg.dev/soloio-img/istio-helm/peering \
  --version $ISTIO_VERSION-solo \
  --namespace istio-gateways \
  --kube-context $KUBECONTEXT_CLUSTER3 \
  -f - <<EOF
remote:
  create: true
  items:
    - name: istio-remote-peer-$MESH_NAME_CLUSTER1
      cluster: $MESH_NAME_CLUSTER1
      network: $MESH_NAME_CLUSTER1
      addressType: $CLUSTER1_EW_ADDRESS_TYPE
      address: $CLUSTER1_EW_ADDRESS
      preferredDataplaneServiceType: loadbalancer
      trustDomain: $MESH_NAME_CLUSTER1.local
      region: region1
    - name: istio-remote-peer-$MESH_NAME_CLUSTER2
      cluster: $MESH_NAME_CLUSTER2
      network: $MESH_NAME_CLUSTER2
      addressType: $CLUSTER2_EW_ADDRESS_TYPE
      address: $CLUSTER2_EW_ADDRESS
      preferredDataplaneServiceType: loadbalancer
      trustDomain: $MESH_NAME_CLUSTER2.local
      region: region2
EOF
```


Verify all three clusters are linked
```bash
./solo-istioctl multicluster check --contexts="$KUBECONTEXT_CLUSTER1,$KUBECONTEXT_CLUSTER2,$KUBECONTEXT_CLUSTER3"
```

> **If `cluster3`'s e/w gateway address is a hostname, wait for DNS to propagate before testing.** The same
> caveat from lab `006` applies here, against a LoadBalancer you created a minute ago. An IP address peers
> at once. A DNS name (an AWS ELB or NLB) takes 30–90 seconds to resolve from the other clusters' CoreDNS.
> Until it resolves, istiod on `cluster1` and `cluster2` logs `disconnected, retrying` against `cluster3`,
> no remote `WorkloadEntry` exists for it, and the three-way failover test below skips `cluster3`. Re-run
> `multicluster check` until all three Peers Checks report connected.

## Add cluster3 to the global productpage service

Apply the same global-service label and traffic-distribution annotation used in lab `006` to `cluster3`'s `productpage`
```bash
kubectl --context $KUBECONTEXT_CLUSTER3 -n bookinfo-frontends label service productpage solo.io/service-scope=global --overwrite
kubectl --context $KUBECONTEXT_CLUSTER3 -n bookinfo-frontends annotate service productpage networking.istio.io/traffic-distribution=PreferNetwork --overwrite
```

Confirm the auto-generated `ServiceEntry` for `productpage` (named `autogen.bookinfo-frontends.productpage`) now lists `cluster3` as a remote peer. This CR doesn't store static endpoint IPs — resolution happens dynamically inside istiod — so the way to confirm cluster3 was picked up is to check `subjectAltNames`, which lists the SPIFFE identity of every *remote* cluster serving this workload:
```bash
for CTX in "$KUBECONTEXT_CLUSTER1" "$KUBECONTEXT_CLUSTER2" "$KUBECONTEXT_CLUSTER3"; do
  echo "Checking global ServiceEntry remote peers in $CTX"
  kubectl --context $CTX get serviceentry -n istio-system autogen.bookinfo-frontends.productpage -o jsonpath='{.spec.subjectAltNames}{"\n"}'
done
```

Each cluster's list should include the SPIFFE identities of the *other two* clusters (a cluster never lists itself — its own endpoints are resolved locally). For example, `cluster1`'s list should show `cluster2` and `cluster3`.

## Demonstrate three-way failover

Traffic still enters through `cluster1`'s ingress gateway, exactly as it did in lab `006`.
```bash
SVC=$(kubectl -n istio-system get svc ingress-istio --context $KUBECONTEXT_CLUSTER1 --no-headers | awk '{ print $4 }')
curl http://$SVC/productpage
```

> **No LoadBalancer?** If you are using port-forward, replace `http://$SVC` with `http://localhost:9080` and keep the port-forward to `svc/productpage` from lab `005` running in a separate terminal.

Scale down `productpage-v1` on `cluster1` and `cluster2`, leaving only `cluster3` healthy
```bash
kubectl scale deploy/productpage-v1 -n bookinfo-frontends --replicas 0 --context $KUBECONTEXT_CLUSTER1
kubectl scale deploy/productpage-v1 -n bookinfo-frontends --replicas 0 --context $KUBECONTEXT_CLUSTER2
```

Refresh the browser or re-run curl — the **Reviews** section should now show `cluster3` as the reviewer cluster, since it is the only cluster with a healthy `productpage` endpoint left
```bash
curl http://$SVC/productpage
```

Tail ztunnel logs on `cluster3` in a separate terminal to confirm traffic is landing there
```bash
kubectl logs -n istio-system -l app=ztunnel --context $KUBECONTEXT_CLUSTER3 -f --prefix
```

Restore `productpage-v1` on both `cluster1` and `cluster2`
```bash
kubectl scale deploy/productpage-v1 -n bookinfo-frontends --replicas 1 --context $KUBECONTEXT_CLUSTER1
kubectl scale deploy/productpage-v1 -n bookinfo-frontends --replicas 1 --context $KUBECONTEXT_CLUSTER2
```

Retry the curl command — traffic should route back to `cluster1` now that it is healthy again.

## Next Steps
At this point we have completed the following objectives
- Installed Istio Ambient Mesh on a third cluster, reusing the shared root of trust
- Deployed Bookinfo on `cluster3` and enrolled it in the ambient mesh
- Extended peering from a pair into a full mesh across all three clusters
- Extended the global `productpage` service to `cluster3` and observed three-way failover

If you would like to clean up all workshop resources, including `cluster3`, see `016` for cleanup instructions.
