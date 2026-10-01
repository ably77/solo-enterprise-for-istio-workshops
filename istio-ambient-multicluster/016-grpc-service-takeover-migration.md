# Migrate a Service Between Clusters Without Changing Hostnames

# Objectives
- Run a gRPC server on `cluster1` behind a local waypoint, and a 4-replica copy on `cluster2` behind its own waypoint
- Take over the cluster-local `grpc-server` hostname with `solo.io/service-takeover=true`
- Cut the server over from `cluster1` to `cluster2` while the client keeps dialing `grpc-server`
- Roll back to `cluster1`, then finish the migration by removing the server from `cluster1`

## Prerequisites
- This lab assumes you have completed setup from labs `000-006`. The two clusters must be linked and `./solo-istioctl multicluster check` must pass.
- Lab `015` explains why a waypoint is needed to balance a single gRPC connection. This lab uses the same client, server, and waypoint setup.

Ensure the following environment variables are set:
```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name

export KUBECONTEXT_CLUSTER2=cluster2  # Replace with your actual kubectl context name
```

## Background

Plenty of applications hardcode a cluster-local hostname such as `grpc-server` in a compiled binary, where changing it means a rebuild you may not control. To move such a service to another cluster, the clients have to keep using that name.

By default, a global service gets a new hostname, `<name>.<namespace>.mesh.internal`, and the cluster-local `<name>.<namespace>.svc.cluster.local` hostname keeps only local endpoints. The `solo.io/service-takeover=true` label routes the cluster-local hostname to the global service instead, so a client that dials `grpc-server` can reach endpoints in any peered cluster.

In this lab, `grpc-server` starts on `cluster1` next to the client, behind its own waypoint, and you migrate it to a 4-replica deployment on `cluster2`. The client keeps dialing `grpc-server` for the whole migration. One connection stays balanced per request on whichever cluster serves it, and you can roll back until you delete the `cluster1` Service.

## Set up the client and the target on cluster2

Create the `grpcdemo` namespace on both clusters and enroll it in the ambient mesh, deploy the client on `cluster1`, and deploy the 4-replica server on `cluster2`. If you completed lab `015` and skipped its Cleanup, these commands keep the existing pods running:
```bash
for context in $KUBECONTEXT_CLUSTER1 $KUBECONTEXT_CLUSTER2; do
  kubectl create ns grpcdemo --context $context --dry-run=client -o yaml | kubectl apply --context $context -f -
  kubectl label ns grpcdemo istio.io/dataplane-mode=ambient --overwrite --context $context
done

kubectl apply -f grpc/grpc-client.yaml -n grpcdemo --context $KUBECONTEXT_CLUSTER1
kubectl rollout status deploy/grpc-client -n grpcdemo --context $KUBECONTEXT_CLUSTER1

sed -e "s/value: unset/value: $KUBECONTEXT_CLUSTER2/" grpc/grpc-server.yaml \
  | kubectl apply -n grpcdemo --context $KUBECONTEXT_CLUSTER2 -f -
kubectl rollout status deploy/grpc-server -n grpcdemo --context $KUBECONTEXT_CLUSTER2
```

Expose the `cluster2` server as a global service, and attach a waypoint on `cluster2` to balance a single connection across its four pods:
```bash
kubectl label svc grpc-server -n grpcdemo solo.io/service-scope=global --overwrite --context $KUBECONTEXT_CLUSTER2

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
kubectl label svc grpc-server -n grpcdemo istio.io/use-waypoint=waypoint --overwrite --context $KUBECONTEXT_CLUSTER2
```

## Start with the service on cluster1

Deploy a 2-replica `grpc-server` on `cluster1`. The `sed` sets the cluster name and replica count before the first rollout:
```bash
sed -e "s/value: unset/value: $KUBECONTEXT_CLUSTER1/" -e 's/replicas: 4/replicas: 2/' grpc/grpc-server.yaml \
  | kubectl apply -n grpcdemo --context $KUBECONTEXT_CLUSTER1 -f -
kubectl rollout status deploy/grpc-server -n grpcdemo --context $KUBECONTEXT_CLUSTER1
```

Give it a waypoint on `cluster1`, the same way you did on `cluster2`, so a single gRPC connection is balanced across the local pods:
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
kubectl label svc grpc-server -n grpcdemo istio.io/use-waypoint=waypoint --overwrite --context $KUBECONTEXT_CLUSTER1

# ztunnel learns the new endpoints and waypoint a few seconds after they are ready.
sleep 10
```

Send 100 requests over one connection to the short name, and count by cluster and pod. You run this same test after each step below:
```bash
kubectl exec -n grpcdemo deploy/grpc-client --context $KUBECONTEXT_CLUSTER1 -- \
  /usr/local/bin/client --count 100 grpc://grpc-server:7070 \
  | awk -F= '/Cluster=/{c=$2} /Hostname=/{print c, $2}' | sort | uniq -c | sort -rn
```

The `cluster1` waypoint balances the connection across both local pods:
```sh
  52 cluster1 grpc-server-85c8869bd9-hfh4k
  48 cluster1 grpc-server-85c8869bd9-68lnh
```

## Prepare the migration

Label the `cluster1` Service `global`, and add the takeover label to the Services in both clusters. Each takeover label applies only to the Service in its own cluster:
```bash
kubectl label svc grpc-server -n grpcdemo solo.io/service-scope=global solo.io/service-takeover=true --overwrite --context $KUBECONTEXT_CLUSTER1
kubectl label svc grpc-server -n grpcdemo solo.io/service-takeover=true --overwrite --context $KUBECONTEXT_CLUSTER2
```

Re-run the test. The short name now covers the pods in both clusters, but traffic stays on `cluster1`:
```sh
  51 cluster1 grpc-server-85c8869bd9-hfh4k
  49 cluster1 grpc-server-85c8869bd9-68lnh
```

A takeover Service with no `networking.istio.io/traffic-distribution` annotation defaults to `PreferNetwork`: requests go to healthy endpoints in the caller's own network while any exist. Traffic moves to `cluster2` only when you drain `cluster1`.

## Cut over to cluster2

Detach the `cluster1` waypoint first, while the `cluster1` pods still serve:
```bash
kubectl label svc grpc-server -n grpcdemo istio.io/use-waypoint- --context $KUBECONTEXT_CLUSTER1

# ztunnel stops sending to the waypoint a few seconds after the label change.
sleep 10
```

Re-run the test. ztunnel now handles the connection alone and picks one endpoint for it, so all 100 requests land on one `cluster1` pod. No requests fail:
```sh
 100 cluster1 grpc-server-85c8869bd9-68lnh
```

Scale `cluster1` to zero:
```bash
kubectl scale deploy/grpc-server -n grpcdemo --replicas=0 --context $KUBECONTEXT_CLUSTER1
kubectl wait --for=delete pod -l app=grpc-server -n grpcdemo --context $KUBECONTEXT_CLUSTER1 --timeout=90s
```

Re-run the test. The client still dials `grpc-server`, and the connection now goes to `cluster2`, where the `cluster2` waypoint balances it across all four pods:
```sh
  26 cluster2 grpc-server-54f6774b64-wg5vf
  25 cluster2 grpc-server-54f6774b64-tvmdm
  25 cluster2 grpc-server-54f6774b64-qsqzj
  24 cluster2 grpc-server-54f6774b64-xxzkf
```

> **Detach the waypoint before you scale down.** For the taken-over `svc.cluster.local` hostname, the `cluster1`
> waypoint holds only `cluster1`'s endpoints. If you scale `cluster1` to zero while the waypoint is still attached,
> requests fail until you remove the `istio.io/use-waypoint` label. The same applies if the `cluster1` pods crash
> while the waypoint is attached, so use this procedure for planned migrations only.

## Roll back

Scale `cluster1` back up first, then re-attach its waypoint:
```bash
kubectl scale deploy/grpc-server -n grpcdemo --replicas=2 --context $KUBECONTEXT_CLUSTER1
kubectl rollout status deploy/grpc-server -n grpcdemo --context $KUBECONTEXT_CLUSTER1
sleep 10
kubectl label svc grpc-server -n grpcdemo istio.io/use-waypoint=waypoint --overwrite --context $KUBECONTEXT_CLUSTER1
sleep 10
```

Re-run the test. Traffic is back on `cluster1`, balanced across both pods:
```sh
  51 cluster1 grpc-server-85c8869bd9-2jbnk
  49 cluster1 grpc-server-85c8869bd9-bg8tw
```

## Finish the migration

Cut over again, then remove the server, its Service, and the waypoint from `cluster1`:
```bash
kubectl label svc grpc-server -n grpcdemo istio.io/use-waypoint- --context $KUBECONTEXT_CLUSTER1
kubectl delete deploy/grpc-server -n grpcdemo --context $KUBECONTEXT_CLUSTER1
kubectl wait --for=delete pod -l app=grpc-server -n grpcdemo --context $KUBECONTEXT_CLUSTER1 --timeout=90s
kubectl delete svc/grpc-server gateway/waypoint -n grpcdemo --context $KUBECONTEXT_CLUSTER1
sleep 10
```

Re-run the test. `cluster1` has no `grpc-server` Service now, so the mesh resolves the name from the global service that the `cluster2` takeover label publishes. The client still reaches all four `cluster2` pods:
```sh
  27 cluster2 grpc-server-54f6774b64-qsqzj
  25 cluster2 grpc-server-54f6774b64-wg5vf
  25 cluster2 grpc-server-54f6774b64-tvmdm
  23 cluster2 grpc-server-54f6774b64-xxzkf
```

> **Takeover applies to every caller.** It changes the cluster-local hostname for all clients in the cluster,
> so one client cannot reach remote endpoints while another stays local. The
> `networking.istio.io/traffic-distribution` annotation still applies to a takeover Service. For example, `Any`
> spreads traffic across both clusters while both serve and no `cluster1` waypoint is attached. Confirm the
> application can handle cross-cluster requests before you apply the label. See
> [Takeover](https://docs.solo.io/istio/1.30.x/ambient/multicluster/multi-apps/overview/#takeover) in the Solo docs.


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

## Next Steps
At this point we have completed the following objectives
- Ran a gRPC server on `cluster1` and `cluster2`, each behind its own waypoint
- Took over the cluster-local `grpc-server` hostname
- Migrated the server from `cluster1` to `cluster2` and rolled back, while the client kept dialing `grpc-server`

If you would like to clean up all workshop resources, see `017` for cleanup instructions.
