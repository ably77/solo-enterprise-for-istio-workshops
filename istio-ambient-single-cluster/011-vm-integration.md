# Add a VM Workload to the Mesh

# Objectives
- Onboard a workload running on a VM into the ambient mesh with its own SPIFFE identity
- Call in-mesh services from the VM over mTLS
- Call the VM workload from a pod by a Kubernetes Service name
- Restrict who can reach the VM workload with an identity-based `AuthorizationPolicy`

## Prerequisites
- This lab assumes you have completed labs `001`–`003`, so Bookinfo runs in the ambient mesh.
- A Docker-based local cluster (vind or KinD). In this lab the "VM" is a container that joins the cluster's Docker network. The mesh configuration matches a real VM's; only `docker exec` and a bind mount replace `ssh` and `scp`, so the whole flow runs on a laptop. On GKE or another cloud cluster, follow the [Solo docs for VMs](https://docs.solo.io/istio/1.30.x/ambient/setup/sample-apps/vm-integration/) with a real VM in the cluster's VPC instead, and skip this lab.
- `docker` CLI on your machine.

Ensure the following environment variable is set:
```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name
```

## Background

A workload outside Kubernetes joins the ambient mesh by running its own ztunnel next to it. That ztunnel:

- authenticates to istiod with a bootstrap token and fetches a certificate for each workload on the VM, so each workload gets its own SPIFFE identity
- reaches istiod and the cluster's workloads through the east-west gateway, which is the one address the VM must reach
- accepts inbound mesh traffic on HBONE port `15008` and hands it to the right local workload
- exposes a SOCKS5 proxy on `127.0.0.1:15080` for outbound calls. Apps send mesh traffic to this proxy with `ALL_PROXY` or a proxy flag

`./solo-istioctl vm add-workload` creates the Kubernetes side: a ServiceAccount and a `WorkloadEntry` per workload, a gateway `WorkloadEntry` that represents the VM, a `Service`, and the tokens.

In this lab, the VM is three containers on the cluster's Docker network:

| Container | Plays the role of |
|---|---|
| `vm-1` | The VM itself: its network interface and IP |
| `vm-1-app` | An app running on the VM (Istio's echo app on port `8080`) |
| `vm-1-ztunnel` | ztunnel running on the VM |

`vm-1-app` and `vm-1-ztunnel` share `vm-1`'s network namespace (`--network container:vm-1`), which is what `--network host` gives you on a real VM. Where the lab uses `docker exec vm-1 ...` and `docker cp`, a real VM uses `ssh` and `scp`.

![](../images/vm-integration-singlecluster-1.png)

## Prepare the mesh

The VM's ztunnel authenticates to istiod with the bootstrap token from `vm add-workload`. That token is a long-lived Kubernetes service account token with no audience, and istiod rejects tokens like it by default. Setting `REQUIRE_3P_TOKEN=false` makes istiod accept them.

This relaxes one check: anyone holding a non-expiring service account token for a mesh identity can get a certificate for that identity until the token is deleted. Pods are unaffected, because they use expiring, audience-bound tokens. Keep this setting out of production clusters. It stays in place until lab `013` uninstalls Istio.

```bash
helm upgrade --kube-context $KUBECONTEXT_CLUSTER1 istiod oci://us-docker.pkg.dev/soloio-img/istio-helm/istiod \
  -n istio-system \
  --version 1.30.2-solo \
  --reuse-values \
  --set-string env.REQUIRE_3P_TOKEN=false

kubectl rollout status deploy/istiod -n istio-system --watch --timeout=90s --context $KUBECONTEXT_CLUSTER1
```

Lab `002` already set `PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES=true`, which lets the VM workload's `WorkloadEntry` back a normal Kubernetes `Service`.

Create an east-west gateway. It exposes istiod (`15012`) and the cluster's HBONE port (`15008`) to workloads outside the cluster network:
```bash
kubectl create namespace istio-eastwest --context $KUBECONTEXT_CLUSTER1 --dry-run=client -o yaml | kubectl apply --context $KUBECONTEXT_CLUSTER1 -f -
./solo-istioctl multicluster expose --namespace istio-eastwest --generate --context $KUBECONTEXT_CLUSTER1 | kubectl apply --context $KUBECONTEXT_CLUSTER1 -f -
kubectl wait --for=condition=Programmed gateway/istio-eastwest -n istio-eastwest --timeout=120s --context $KUBECONTEXT_CLUSTER1
kubectl get gateway istio-eastwest -n istio-eastwest --context $KUBECONTEXT_CLUSTER1
```

Expected output (the address differs on your machine):
```
NAME             CLASS            ADDRESS          PROGRAMMED   AGE
istio-eastwest   istio-eastwest   172.18.255.254   True         10s
```

> **No address?** The gateway Service is type `LoadBalancer`. vind assigns one on the Docker network. On KinD, install [cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind) first.

## Start the VM

Find the Docker network your cluster's nodes are on. This matches a node's IP against every Docker network, so it works for vind and KinD:
```bash
NODE_IP=$(kubectl get nodes --context $KUBECONTEXT_CLUSTER1 -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
export VM_DOCKER_NETWORK=""
for NET in $(docker network ls --format '{{.Name}}'); do
  docker network inspect "$NET" --format '{{range .Containers}}{{.IPv4Address}} {{end}}' | tr ' ' '\n' | grep -qx "$NODE_IP/[0-9]*" && VM_DOCKER_NETWORK=$NET
done
[ -n "$VM_DOCKER_NETWORK" ] && echo "Cluster Docker network: $VM_DOCKER_NETWORK" \
  || echo "⚠️  No Docker network contains node IP $NODE_IP. This lab needs a Docker-based cluster (vind or KinD). Set VM_DOCKER_NETWORK by hand if your nodes are containers."
```

Start the VM and its app. The app is Istio's echo server listening on `8080`; it replies with its version and hostname:
```bash
if [ -z "$VM_DOCKER_NETWORK" ]; then
  echo "⚠️  VM_DOCKER_NETWORK is empty. Stop here: this lab needs a Docker-based cluster."
else
  docker rm -f vm-1-ztunnel vm-1-app vm-1 2>/dev/null
  docker run -d --name vm-1 --hostname vm-1 --network "$VM_DOCKER_NETWORK" nicolaka/netshoot sleep infinity
  docker run -d --name vm-1-app --network container:vm-1 docker.io/istio/app:1.30.2 --port 8080 --version vm-1

  export VM_IP=$(docker inspect vm-1 --format "{{(index .NetworkSettings.Networks \"$VM_DOCKER_NETWORK\").IPAddress}}")
  echo "VM IP: $VM_IP"
fi
```

Check that the app answers on the VM and that the VM can reach istiod through the east-west gateway:
```bash
EW_ADDRESS=$(kubectl get gateway istio-eastwest -n istio-eastwest --context $KUBECONTEXT_CLUSTER1 -o jsonpath='{.status.addresses[0].value}')
docker exec vm-1 curl -s localhost:8080 | grep -E 'ServiceVersion|Hostname'
docker exec vm-1 nc -zv -w2 "$EW_ADDRESS" 15012
```

Expected output:
```
ServiceVersion=vm-1
Hostname=vm-1
Connection to 172.18.255.254 15012 port [tcp/*] succeeded!
```

## Onboard the VM workload

Create a namespace for the VM's workloads and add it to the ambient mesh:
```bash
kubectl create namespace vm-apps --context $KUBECONTEXT_CLUSTER1 --dry-run=client -o yaml | kubectl apply --context $KUBECONTEXT_CLUSTER1 -f -
kubectl label namespace vm-apps istio.io/dataplane-mode=ambient --overwrite --context $KUBECONTEXT_CLUSTER1
```

Register the app as workload `app1`. `--external` tells the mesh to reach the VM through the east-west gateway, `--ports http:80:8080` maps Service port `80` to the app's port `8080`, and `--hostname` must match the VM's hostname:
```bash
mkdir -p ./vm-tokens
VM_IP=$(docker inspect vm-1 --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
./solo-istioctl vm add-workload app1 \
  --external \
  --address "$VM_IP" \
  --namespace vm-apps \
  --ports http:80:8080 \
  --hostname vm-1 \
  --output-dir ./vm-tokens \
  --context $KUBECONTEXT_CLUSTER1 | tee ./vm-tokens/add-workload.out
```

Expected output (abridged):
```
• Generated authentication token for vm-apps/app1
• Created WorkloadEntry vm-apps/vm-app1
• Created Service vm-apps/app1
• Created gateway WorkloadEntry vm-apps/vm-vm-1-gateway
• Generating a bootstrap token for vm-apps/vm-gateway...
  • Service "istio-eastwest" provides Istiod access on port 15012
...
Start ztunnel on the VM with:
  BOOTSTRAP_TOKEN=<token> ztunnel
• Wrote workload token to vm-tokens/app1.token
```

The output holds the bootstrap token, which ztunnel uses to authenticate to istiod as the VM (`vm-gateway`). The workload token for `app1` is in `./vm-tokens/app1.token`, and ztunnel reads it from `/etc/ztunnel/tokens/<namespace>/<workload>/token`. Both are credentials.

Save the bootstrap token and lay out the workload token in the directory you mount into ztunnel. On a real VM this is an `scp` to `/etc/ztunnel`:
```bash
TOKEN=$(grep -o 'BOOTSTRAP_TOKEN=[^ ]*' ./vm-tokens/add-workload.out | head -1 | cut -d= -f2-)
[ -n "$TOKEN" ] && printf '%s' "$TOKEN" > ./vm-tokens/bootstrap.token
[ -s ./vm-tokens/bootstrap.token ] || echo "⚠️  No bootstrap token in the output. The VM gateway already existed, so add-workload did not generate one. Re-run the add-workload command with --bootstrap, then run this block again."

mkdir -p ./vm-config/tokens/vm-apps/app1
cp ./vm-tokens/app1.token ./vm-config/tokens/vm-apps/app1/token
```

Start ztunnel on the VM:
```bash
docker rm -f vm-1-ztunnel 2>/dev/null
docker run -d --name vm-1-ztunnel \
  --network container:vm-1 \
  -e HOSTNAME=vm-1 \
  -e BOOTSTRAP_TOKEN="$(cat ./vm-tokens/bootstrap.token)" \
  -v "$PWD/vm-config:/etc/ztunnel:ro" \
  us-docker.pkg.dev/soloio-img/istio/ztunnel:1.30.2-solo-distroless
```

Check that ztunnel connected to istiod, accepted the license, and provisioned a listener for `app1`:
```bash
sleep 5
docker logs vm-1-ztunnel 2>&1 | grep -E 'detected license|proxying to XDS|provisioned inbound listener'
```

Expected output:
```
... info  xds::client:xds{id=1}  detected license  state=OK
... info  proxy::gateway  proxying to XDS server  xds_address="172.18.255.254:15012"
... info  proxy::gateway::xds_workload_provisioner  provisioned inbound listener for XDS workload  component="xds-workload-provisioner" port=15100 workload=vm-apps/app1
```

Look at what `add-workload` created, and at the mesh's view of it:
```bash
kubectl get workloadentry,svc,serviceaccount -n vm-apps --context $KUBECONTEXT_CLUSTER1
./solo-istioctl ztunnel-config workloads --context $KUBECONTEXT_CLUSTER1 | grep -E 'NAMESPACE|vm-apps'
./solo-istioctl ztunnel-config services --context $KUBECONTEXT_CLUSTER1 | grep -E 'NAMESPACE|vm-apps'
```

Expected output (abridged):
```
NAMESPACE  POD NAME         ADDRESS      NODE  WAYPOINT PROTOCOL NETWORK  NETWORK GATEWAY
vm-apps    vm-app1          127.0.0.1    vm-1  None     HBONE    cluster1 cluster1/172.18.0.4
vm-apps    vm-vm-1-gateway  172.18.0.4   vm-1  None     HBONE    cluster1 cluster1/172.18.255.254

NAMESPACE  SERVICE NAME  SERVICE VIP    WAYPOINT ENDPOINTS
vm-apps    app1          10.111.64.111  None     1/1
```

`vm-app1` has address `127.0.0.1` and network gateway `vm-1`'s IP: the mesh reaches `app1` by tunnelling to the VM, and the VM's ztunnel delivers to the app on localhost. `vm-vm-1-gateway` is the VM itself, reached through the east-west gateway. `app1` has `1/1` endpoints because lab `002` set `PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES=true`, so Services select `WorkloadEntry` resources.

## Call the mesh from the VM

Apps on the VM send outbound mesh traffic through ztunnel's SOCKS5 proxy. The SOCKS5 username picks the identity: `<workload>.<namespace>`. The password is ignored. Call `productpage` as `app1`:
```bash
docker exec vm-1 curl -s -o /dev/null -w '%{http_code}\n' \
  -x socks5h://app1.vm-apps:pass@127.0.0.1:15080 \
  http://productpage.bookinfo-frontends:9080/productpage
```

Expected output:
```
200
```

With the `socks5h` scheme, ztunnel resolves the service name, so the VM uses the mesh's DNS. The ztunnel on `productpage`'s node logged the caller's identity:
```bash
kubectl logs ds/ztunnel -n istio-system --all-pods --since=1m --context $KUBECONTEXT_CLUSTER1 2>/dev/null \
  | grep 'http_access' | grep 'sa/app1' | tail -1
```

Expected output (abridged):
```
... src.identity="spiffe://cluster1.local/ns/vm-apps/sa/app1" ... dst.service="productpage.bookinfo-frontends.svc.cluster.local" ... response_code=200 ...
```

The request left the VM over mTLS with `app1`'s identity, crossed the east-west gateway, and reached `productpage` over HBONE, the same path a pod's request takes.

Every outbound call needs an identity. Without a SOCKS5 username, ztunnel refuses the connection:
```bash
docker exec vm-1 curl -s -o /dev/null -w '%{http_code}\n' -m 5 \
  -x socks5h://127.0.0.1:15080 \
  http://productpage.bookinfo-frontends:9080/productpage
docker logs vm-1-ztunnel --since 30s 2>&1 | grep SOCKS5_REQUIRE_IDENTITY
```

Expected output:
```
000
... warn  proxy::socks5 ...  SOCKS5 connection rejected: SOCKS5_REQUIRE_IDENTITY is enabled but no username provided
```

## Call the VM from the mesh

Pods reach the VM workload by its Service name, `app1.vm-apps`. Call it from `productpage`:
```bash
kubectl exec deploy/productpage-v1 -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1 -- \
  python -c "import urllib.request; print(urllib.request.urlopen('http://app1.vm-apps', timeout=5).read().decode())" \
  | grep -E 'ServiceVersion|Hostname'
```

Expected output:
```
ServiceVersion=vm-1
Hostname=vm-1
```

The VM's ztunnel logged the inbound connection with the caller's identity:
```bash
docker logs vm-1-ztunnel --since 1m 2>&1 | grep 'direction="inbound"' | tail -1
```

Expected output (abridged):
```
... src.identity="spiffe://cluster1.local/ns/bookinfo-frontends/sa/bookinfo-productpage" dst.addr=127.0.0.1:15100 ... dst.workload="vm-app1" ... dst.identity="spiffe://cluster1.local/ns/vm-apps/sa/app1" direction="inbound" ...
```

The client's ztunnel opened a tunnel to the VM on port `15008`, and the VM's ztunnel passed it to `app1`'s own listener on `15100`, which terminated mTLS as `app1` and handed plain HTTP to the app on localhost.

## Restrict access by identity

`app1` has its own identity, so policies select it the same way they select a pod. `add-workload` labels the `WorkloadEntry` with `vm.solo.io/workload: app1`; the policy selects that label and allows only `productpage`'s service account:
```bash
cat vm/app1-allow-productpage.yaml
kubectl apply -f vm/app1-allow-productpage.yaml --context $KUBECONTEXT_CLUSTER1
```

Call `app1` from `productpage` (allowed) and from `reviews-v1` (not allowed):
```bash
sleep 3
kubectl exec deploy/productpage-v1 -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1 -- \
  python -c "import urllib.request; print(urllib.request.urlopen('http://app1.vm-apps', timeout=5).status)"
kubectl exec deploy/reviews-v1 -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1 -- \
  curl -s -o /dev/null -w '%{http_code}\n' -m 5 http://app1.vm-apps
```

Expected output:
```
200
000
command terminated with exit code 56
```

The VM's ztunnel enforced the policy and logged why it closed the `reviews` connection:
```bash
docker logs vm-1-ztunnel --since 1m 2>&1 | grep 'policy rejection' | tail -1
```

Expected output (abridged):
```
... src.identity="spiffe://cluster1.local/ns/bookinfo-backends/sa/bookinfo-reviews" ... dst.workload="vm-app1" ... error="connection closed due to policy rejection: allow policies exist, but none allowed"
```

## Going further
- To add more workloads to the same VM, run `vm add-workload` again with another name and port, the same `--address`, and `--hostname vm-1`, then copy the new workload token to `vm-config/tokens/vm-apps/<workload>/token`. The VM's ztunnel picks up the new workload from istiod without a restart. The existing bootstrap token stays valid.
- For single-workload VMs, the [Solo docs](https://docs.solo.io/istio/1.30.x/ambient/setup/sample-apps/vm-integration/#single) describe the legacy `istioctl bootstrap` path.
- On a real VM, replace `docker exec vm-1` with `ssh`, `docker cp`/the bind mount with `scp` to `/etc/ztunnel`, and `--network container:vm-1` with `--network host`.

## Cleanup

Stop the VM's containers and delete the tokens:
```bash
docker rm -f vm-1-ztunnel vm-1-app vm-1 2>/dev/null
rm -rf ./vm-tokens ./vm-config
```

Remove the VM namespace and the east-west gateway:
```bash
kubectl delete namespace vm-apps istio-eastwest --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
```

To run a MySQL database on a VM in the mesh, continue to lab `012`.

istiod keeps `REQUIRE_3P_TOKEN=false` until you uninstall Istio. If you would like to clean up all workshop resources, see `013` for cleanup instructions.
