# Cross-Cluster gRPC Load Balancing

# Objectives
- Split a gRPC client and a 4-replica server across `cluster1` and `cluster2`
- Expose the server as a global service
- Reproduce gRPC connection pinning across the cluster boundary
- Review waypoint placement
- Restore per-request load balancing across the boundary and trace the path
- Keep the client dialing a cluster-local hostname with `solo.io/service-takeover`
- Add local endpoints to `cluster1` and watch `PreferNetwork` and `Any`

## Prerequisites
- This lab assumes you have completed setup from labs `000-006`. The two clusters must be linked and `./solo-istioctl multicluster check` must pass. Traffic in this lab uses the east-west gateways created in lab `006`.

Ensure the following environment variables are set:
```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name

export KUBECONTEXT_CLUSTER2=cluster2  # Replace with your actual kubectl context name
```

## Background

gRPC multiplexes many requests over one long-lived HTTP/2 connection, and Kubernetes load balances
*connections*, resulting in inefficient connection pooling. The [single-cluster version of this
lab](../istio-ambient-single-cluster/010-grpc-loadbalancing.md) reproduces that premise in detail and fixes
it with a waypoint, in one cluster, with no application change.

This lab extends the single cluster example to demonstrate that the same gRPC load balancing mechanism still
applies across a global mesh. The client runs on `cluster1` and the 4-replica server on `cluster2`, where a
single `solo.io/service-scope=global` label publishes the server at `grpc-server.grpcdemo.mesh.internal` in
every peered cluster. A waypoint then restores per-request load balancing across pods in another cluster,
with no local copy of the Service on `cluster1`, no external load balancer, and no application change.

Both workloads use **Istio's echo app** (`docker.io/istio/app`), the same app Istio's own multicluster
integration tests drive. Two of its properties do the work in this lab:

- Its responses carry `Hostname=` and `Cluster=`, so every count below reports which pod *and* which cluster served the request.
- Its client has a `--new-connection-per-request` flag, so you can toggle connection reuse on one binary and compare the two runs.

# Part 1: Split the client and server across the clusters

Create the `grpcdemo` namespace on both clusters and enroll it in the ambient mesh:
```bash
for context in $KUBECONTEXT_CLUSTER1 $KUBECONTEXT_CLUSTER2; do
  kubectl create ns grpcdemo --context $context --dry-run=client -o yaml | kubectl apply --context $context -f -
  kubectl label ns grpcdemo istio.io/dataplane-mode=ambient --overwrite --context $context
done
```

Deploy the client on `cluster1`:
```bash
kubectl apply -f grpc/grpc-client.yaml -n grpcdemo --context $KUBECONTEXT_CLUSTER1
kubectl rollout status deploy/grpc-client -n grpcdemo --context $KUBECONTEXT_CLUSTER1
```

Deploy the 4-replica server on `cluster2`. The manifest passes `--cluster=$(CLUSTER_NAME)`, which Kubernetes expands from the container's environment, so the serving cluster shows up in every response:
```bash
kubectl apply -f grpc/grpc-server.yaml -n grpcdemo --context $KUBECONTEXT_CLUSTER2
kubectl set env deploy/grpc-server -n grpcdemo CLUSTER_NAME=$KUBECONTEXT_CLUSTER2 --context $KUBECONTEXT_CLUSTER2
kubectl rollout status deploy/grpc-server -n grpcdemo --context $KUBECONTEXT_CLUSTER2
```

> **The `grpc-server` Service port has to declare gRPC.** The manifest sets `appProtocol: grpc` and names
> the port `grpc`. Either signal tells Istio to parse HTTP/2 off the connection. Without one, a waypoint
> treats the stream as opaque TCP and pins every request to one pod. A global service carries the port
> definition to the peered clusters, so you set this only where the Service is defined.

`cluster1` holds only the client, with no `grpc-server` Deployment or Service at all:
```bash
kubectl get pods,svc -n grpcdemo --context $KUBECONTEXT_CLUSTER1
```

# Part 2: Make the server reachable

## Both hostnames fail

The ordinary cluster-local name does not resolve, because there is no such Service on `cluster1`:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 1 grpc://grpc-server:7070
```

```sh
fatal	Error 1/1 requests had errors; first error: rpc error: code = Unavailable desc = connection error:
desc = "transport: Error while dialing: dial tcp: lookup grpc-server on 10.109.68.100:53: no such host"
```

The global hostname does not resolve either:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 1 grpc://grpc-server.grpcdemo.mesh.internal:7070
```

```sh
fatal	Error 1/1 requests had errors; first error: rpc error: code = Unavailable desc = connection error:
desc = "transport: Error while dialing: dial tcp: lookup grpc-server.grpcdemo.mesh.internal on 10.109.68.100:53: no such host"
```

Peering the clusters in lab `006` did not make their services mutually reachable. Services stay cluster-scoped until you label them global.

## Expose it as a global service

Apply the `solo.io/service-scope=global` label to the `grpc-server` service on `cluster2`. This generates a `ServiceEntry` for the hostname `grpc-server.grpcdemo.mesh.internal` in **every** peered cluster, aggregating the endpoints of each cluster that hosts the service:
```bash
kubectl label svc grpc-server -n grpcdemo solo.io/service-scope=global --overwrite --context $KUBECONTEXT_CLUSTER2
```

Confirm the global `ServiceEntry` reached both clusters:
```bash
for context in $KUBECONTEXT_CLUSTER1 $KUBECONTEXT_CLUSTER2; do
  echo "--- $context ---"
  kubectl get serviceentry -n istio-system --context $context | grep -E "NAME|grpc-server"
done
```

Both clusters report it, even though only `cluster2` has a `grpc-server` Service. Consuming a global
service takes no local copy of it, so `cluster1` needs no `grpc-server` Deployment and no placeholder
Service. It learns the hostname over the peering established in lab `006` and generates the
`ServiceEntry` itself:
```sh
NAME                         HOSTS                                    LOCATION        RESOLUTION   AGE
autogen.grpcdemo.grpc-server ["grpc-server.grpcdemo.mesh.internal"]   MESH_INTERNAL   STATIC       5s
```

Dial the global hostname and count by cluster:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 grpc://grpc-server.grpcdemo.mesh.internal:7070 \
  | grep Cluster= | sed 's/.*Cluster=//' | sort | uniq -c
```

All 100 requests cross the boundary, from the `--cluster` value you set on the server deployment:
```sh
 100 cluster2
```

# Part 3: The pinning, across the boundary

Reachability looks fine. Now look at *which* pods serve the traffic.

Send 100 requests **with a new connection for each one**. Piping through `sort | uniq -c` collapses the output into a count per server pod:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 --new-connection-per-request \
  grpc://grpc-server.grpcdemo.mesh.internal:7070 \
  | grep Hostname= | sed 's/.*Hostname=//' | sort | uniq -c | sort -rn
```

The requests spread across all four remote pods:
```sh
  31 grpc-server-54f6774b64-j49mq
  29 grpc-server-54f6774b64-lz4t5
  26 grpc-server-54f6774b64-f6nm6
  14 grpc-server-54f6774b64-2wjpk
```

No L7 proxy sits anywhere in this path. ztunnel balances at L4, and it succeeds here because each request arrives on its own connection. A quick test therefore looks healthy and hides the problem. Tools like `grpcurl` open a fresh connection per invocation, so they never reproduce it.

Run the identical command with connection reuse, which is what a production gRPC client does:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 \
  grpc://grpc-server.grpcdemo.mesh.internal:7070 \
  | grep Hostname= | sed 's/.*Hostname=//' | sort | uniq -c | sort -rn
```

All 100 requests land on a single pod:
```sh
 100 grpc-server-54f6774b64-j49mq
```

You changed one flag on the same binary, against the same mesh and the same global service, and the four-replica deployment now serves like one. ztunnel gives you mTLS and L4 authorization on the tunnel, then forwards that one connection to one endpoint.

# Part 4: A waypoint, in the backend cluster

You can deploy a waypoint on `cluster1`, and the client's traffic does go through it. It just has nothing
useful to balance over. In Ambient, a waypoint load balances only over endpoints in its own cluster, and from
`cluster1`, `cluster2`'s four pods are not four endpoints: they collapse into the single east-west gateway
address that fronts the peer. The waypoint sees one endpoint, opens one tunnel to it, `cluster2`'s ztunnel
pins that tunnel to a pod, and the requests stay on one pod.

Adding a waypoint on `cluster2` as well does not rescue it. Waypoints do not chain, so once a request has
passed through one, the destination cluster's waypoint is skipped. A waypoint on the client side is therefore
worse than useless here: it holds the traffic at L7 in the cluster that cannot spread it, and keeps it away
from the waypoint that could. Part 7 returns to this once `cluster1` hosts endpoints of its own, where a
waypoint there does have pods to balance across.

Put the waypoint where the endpoints are. Deploy it into `grpcdemo` on `cluster2` and enroll the namespace:
```bash
kubectl apply --context $KUBECONTEXT_CLUSTER2 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: grpcdemo
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
    allowedRoutes:
      namespaces:
        from: All
EOF
kubectl rollout status deploy/waypoint -n grpcdemo --context $KUBECONTEXT_CLUSTER2
kubectl label ns grpcdemo istio.io/use-waypoint=waypoint --overwrite --context $KUBECONTEXT_CLUSTER2
```

The `istio.io/use-waypoint=waypoint` label marks every service in `grpcdemo` on `cluster2` as reached through that waypoint, including `grpc-server`, which the global hostname resolves to. `cluster1`'s ztunnel still sends the client's connection across the boundary at L4, and `cluster2`'s ztunnel now hands it to the waypoint instead of straight to a pod.

Re-run the connection-reuse test from Part 3, the one that pinned all 100 requests. The client is not reconfigured and has never restarted:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 grpc://grpc-server.grpcdemo.mesh.internal:7070 \
  | grep Hostname= | sed 's/.*Hostname=//' | sort | uniq -c | sort -rn
```

One connection carrying 100 multiplexed requests now reaches four pods in another cluster:
```sh
  29 grpc-server-54f6774b64-lz4t5
  25 grpc-server-54f6774b64-j49mq
  24 grpc-server-54f6774b64-f6nm6
  22 grpc-server-54f6774b64-2wjpk
```

`cluster2` reports the endpoints its waypoint balances across:
```bash
./solo-istioctl ztunnel-config service --service-namespace grpcdemo --context $KUBECONTEXT_CLUSTER2
```

```sh
NAMESPACE SERVICE NAME                 SERVICE VIP             WAYPOINT ENDPOINTS
grpcdemo  autogen.grpcdemo.grpc-server 240.240.0.19,2001:2::13 waypoint 4/4
grpcdemo  autogen.grpcdemo.waypoint    240.240.0.20,2001:2::14 None     1/1
grpcdemo  grpc-server                  10.110.219.34           waypoint 4/4
grpcdemo  waypoint                     10.109.159.166          None     1/1
```

`ENDPOINTS 4/4`, one per backend pod, and the waypoint balances across all of them. No application code changed, no external load balancer was added, and the client was never touched.

> **`ENDPOINTS` is how you catch the wrong placement.** Run the same `ztunnel-config service` command
> against `cluster1` and the global service reports `1/1`, because from there the whole of `cluster2` is a
> single east-west gateway address. `1/1` for a service you know has four pods means a waypoint in that
> cluster would have nothing to balance over, and `proxy-config endpoint` on such a waypoint would list the
> peer gateway address where pod IPs should be.

# Part 5: Trace the path

The request path is now: client pod → `cluster1` ztunnel → `cluster1` east-west gateway → `cluster2` east-west gateway → `cluster2` ztunnel → **`cluster2` waypoint** → server pod. The client's connection crosses the boundary at L4, and nothing terminates it until it reaches the waypoint next to the backends.

Four real pod IPs back the global hostname on `cluster2`:
```bash
./solo-istioctl proxy-config endpoint deploy/waypoint -n grpcdemo --context $KUBECONTEXT_CLUSTER2 \
  | grep "mesh.internal" | grep connect_originate
```

```sh
envoy://connect_originate/10.244.0.15:7070    HEALTHY   OK   inbound-vip|7070|http|grpc-server.grpcdemo.mesh.internal
envoy://connect_originate/10.244.2.50:7070    HEALTHY   OK   inbound-vip|7070|http|grpc-server.grpcdemo.mesh.internal
envoy://connect_originate/10.244.2.51:7070    HEALTHY   OK   inbound-vip|7070|http|grpc-server.grpcdemo.mesh.internal
envoy://connect_originate/10.244.2.52:7070    HEALTHY   OK   inbound-vip|7070|http|grpc-server.grpcdemo.mesh.internal
```

Send another 100 requests, then read the `cluster2` ztunnel log:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 grpc://grpc-server.grpcdemo.mesh.internal:7070 > /dev/null

kubectl logs -n istio-system -l app=ztunnel --context $KUBECONTEXT_CLUSTER2 --since=60s --prefix \
  | grep "connection complete" | grep 'src.workload="waypoint'
```

One connection per server pod, each carrying the **`cluster2`** waypoint's SPIFFE identity in `src.identity`. The waypoint terminated the client's connection and opened its own to each backend:
```sh
src.workload="waypoint-77f666585d-csj8l" src.identity="spiffe://cluster2.local/ns/grpcdemo/sa/waypoint" dst.workload="grpc-server-54f6774b64-j49mq" bytes_sent=12255
src.workload="waypoint-77f666585d-csj8l" src.identity="spiffe://cluster2.local/ns/grpcdemo/sa/waypoint" dst.workload="grpc-server-54f6774b64-2wjpk" bytes_sent=12255
src.workload="waypoint-77f666585d-csj8l" src.identity="spiffe://cluster2.local/ns/grpcdemo/sa/waypoint" dst.workload="grpc-server-54f6774b64-lz4t5" bytes_sent=11776
src.workload="waypoint-77f666585d-csj8l" src.identity="spiffe://cluster2.local/ns/grpcdemo/sa/waypoint" dst.workload="grpc-server-54f6774b64-f6nm6" bytes_sent=12734
```

`connection complete` logs when a connection closes, so give the run a moment to finish before reading. In the pinned runs earlier, one such line carried the client's own `spiffe://cluster1.local/ns/grpcdemo/sa/default` identity to one pod.

# Part 6: Keep a cluster-local hostname

The client dials `grpc-server.grpcdemo.mesh.internal`, a hostname it had to be told about because the server lives in another cluster. Plenty of applications hardcode a cluster-local hostname in a compiled binary, where changing it means a rebuild you may not control.

`solo.io/service-takeover=true` rewrites the cluster-local `grpc-server.grpcdemo.svc.cluster.local` hostname to the global one, so an unmodified client reaches remote endpoints. Available in Solo Istio 1.27.2 and later:
```bash
kubectl label svc grpc-server -n grpcdemo solo.io/service-takeover=true --overwrite --context $KUBECONTEXT_CLUSTER2
```

Dial `grpc-server:7070`, the short name that failed to resolve in Part 2:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 grpc://grpc-server:7070 \
  | grep Hostname= | sed 's/.*Hostname=//' | sort | uniq -c | sort -rn
```

The cluster-local hostname now balances across four pods in another cluster:
```sh
  26 grpc-server-54f6774b64-lz4t5
  26 grpc-server-54f6774b64-2wjpk
  25 grpc-server-54f6774b64-j49mq
  23 grpc-server-54f6774b64-f6nm6
```

`cluster1` has no `grpc-server` Service to answer that name. The mesh answers the short name from the global service, so a cluster needs no placeholder Service to consume, or to take over, a service hosted elsewhere. Takeover applies to every caller of that hostname, so you give up per-caller control over whether a service reaches local endpoints only.

Remove the label before continuing:
```bash
kubectl label svc grpc-server -n grpcdemo solo.io/service-takeover- --context $KUBECONTEXT_CLUSTER2
```

# Part 7: Local endpoints and locality

Give `cluster1` its own copy of the service, so the global service has endpoints in both clusters. A cluster contributes endpoints by hosting the service locally with the global label:
```bash
kubectl apply -f grpc/grpc-server.yaml -n grpcdemo --context $KUBECONTEXT_CLUSTER1
kubectl scale deploy/grpc-server -n grpcdemo --replicas 2 --context $KUBECONTEXT_CLUSTER1
kubectl set env deploy/grpc-server -n grpcdemo CLUSTER_NAME=$KUBECONTEXT_CLUSTER1 --context $KUBECONTEXT_CLUSTER1
kubectl label svc grpc-server -n grpcdemo solo.io/service-scope=global --overwrite --context $KUBECONTEXT_CLUSTER1
kubectl rollout status deploy/grpc-server -n grpcdemo --context $KUBECONTEXT_CLUSTER1
```

Count by cluster:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 grpc://grpc-server.grpcdemo.mesh.internal:7070 \
  | grep Cluster= | sed 's/.*Cluster=//' | sort | uniq -c
```

All 100 requests now report `cluster1`. Traffic distribution defaults to `PreferNetwork` for a global backend: while local endpoints stay healthy it keeps traffic in-network, and the four `cluster2` pods drop to a lower priority as failover capacity.
```sh
 100 cluster1
```

Now count by pod:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 grpc://grpc-server.grpcdemo.mesh.internal:7070 \
  | grep Hostname= | sed 's/.*Hostname=//' | sort | uniq -c | sort -rn
```

All 100 land on one of the two local pods:
```sh
 100 grpc-server-85c8869bd9-l7z6j
```

`cluster1` serves this traffic locally now, and Part 4 put the only waypoint in `cluster2`, so nothing terminates the client's HTTP/2 connection. The rule from Part 4 applies again, in the other direction: a waypoint belongs in every cluster that serves endpoints, and `cluster1` just became one. Deploy a waypoint there too:
```bash
kubectl apply --context $KUBECONTEXT_CLUSTER1 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: grpcdemo
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
    allowedRoutes:
      namespaces:
        from: All
EOF
kubectl rollout status deploy/waypoint -n grpcdemo --context $KUBECONTEXT_CLUSTER1
kubectl label ns grpcdemo istio.io/use-waypoint=waypoint --overwrite --context $KUBECONTEXT_CLUSTER1

kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 grpc://grpc-server.grpcdemo.mesh.internal:7070 \
  | grep Hostname= | sed 's/.*Hostname=//' | sort | uniq -c | sort -rn
```

Requests balance across both local pods:
```sh
  51 grpc-server-85c8869bd9-wc2z8
  49 grpc-server-85c8869bd9-l7z6j
```

## What `Any` changes

Setting the traffic distribution mode to `Any` releases the locality preference:
```bash
for context in $KUBECONTEXT_CLUSTER1 $KUBECONTEXT_CLUSTER2; do
  kubectl annotate svc grpc-server -n grpcdemo \
    networking.istio.io/traffic-distribution=Any --overwrite --context $context
done

kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 grpc://grpc-server.grpcdemo.mesh.internal:7070 \
  | grep Cluster= | sed 's/.*Cluster=//' | sort | uniq -c
```

Traffic splits across both clusters:
```sh
  49 cluster1
  51 cluster2
```

Count by pod:
```sh
  51 grpc-server-54f6774b64-f6nm6    <- cluster2, all 51 on one pod
  25 grpc-server-85c8869bd9-l7z6j    <- cluster1
  24 grpc-server-85c8869bd9-wc2z8    <- cluster1
```

The `cluster1` waypoint sees three endpoints: two local pods, and one east-west gateway standing in for everything in `cluster2`. It spreads requests across those three, so the `cluster2` share arrives as a single multiplexed tunnel and ztunnel pins it to one pod. `cluster2`'s waypoint never engages, because the traffic already traversed a waypoint on the client side.

**`Any` balances across clusters**, and stops there. Per-request fan-out over a remote cluster's pods needs traffic to reach that cluster without passing through a waypoint first, which is what Part 4 arranges.

## Cleanup

Remove the namespace from both clusters, which takes the waypoints, the apps, and the labels with it:
```bash
for context in $KUBECONTEXT_CLUSTER1 $KUBECONTEXT_CLUSTER2; do
  kubectl delete ns grpcdemo --context $context --ignore-not-found
done
```

Istio garbage collects the autogenerated `ServiceEntry` objects in `istio-system` once the services are gone. Confirm:
```bash
for context in $KUBECONTEXT_CLUSTER1 $KUBECONTEXT_CLUSTER2; do
  kubectl get serviceentry -n istio-system --context $context | grep grpc-server
done
```

Both commands should return nothing.

## Summary

At this point we have completed the following objectives:
- Split a gRPC client and a 4-replica server across `cluster1` and `cluster2`, and watched both hostnames fail to resolve, because peering shares no services on its own
- Exposed the server as a global service reachable at `grpc-server.grpcdemo.mesh.internal`, with no copy of it on `cluster1`
- Reproduced connection pinning across the boundary: a connection per request spread over all four remote pods, and the same command with connection reuse collapsed to one
- Deployed the waypoint in `cluster2` with the backends rather than in `cluster1` with the client, and distributed 100 multiplexed requests across four pods in another cluster without touching the client
- Read `ENDPOINTS 4/4` from `ztunnel-config service` as confirmation the waypoint balances over real pods, and learned that `1/1` on a four-pod service is how the wrong placement shows up
- Traced the path through the east-west gateways, the `cluster2` ztunnel, and the `cluster2` waypoint
- Used `solo.io/service-takeover` so the client reached `cluster2` through a plain cluster-local hostname
- Watched `PreferNetwork` pull traffic to local endpoints and pin it with no local waypoint, and saw `Any` balance across clusters while the remote share landed on one pod

A waypoint load balances gRPC at the request level with no application change and no external load balancer, in one cluster or across two. Multicluster adds one placement rule:

> **A waypoint load balances only over endpoints in its own cluster.** Remote endpoints collapse into a
> single east-west gateway address, leaving a client-side waypoint nothing to spread traffic over. Put a
> waypoint in every cluster that runs backends, and let cross-cluster traffic arrive at L4 so the
> destination cluster's waypoint fans it out.

The single-cluster workshop has a [same-cluster version of this lab](../istio-ambient-single-cluster/010-grpc-loadbalancing.md), which reproduces the pinning and the waypoint fix with the client and server side by side.
