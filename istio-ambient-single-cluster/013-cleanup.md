# Cleanup

Remove all workshop resources from the cluster.

## Solo Management UI

```bash
helm uninstall management -n kagent --kube-context $KUBECONTEXT_CLUSTER1
kubectl delete namespace kagent --context $KUBECONTEXT_CLUSTER1
```

## Ingress gateway and routes

```bash
kubectl delete httproute bookinfo-route -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
kubectl delete gateway ingress -n istio-system --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
```

## Bookinfo application

```bash
kubectl delete namespace bookinfo-frontends bookinfo-backends --context $KUBECONTEXT_CLUSTER1
```

## gRPC demo (lab `010`)

```bash
kubectl delete namespace grpcdemo --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
```

## VM integration (lab `011`)

```bash
docker rm -f vm-1-ztunnel vm-1-app vm-1 2>/dev/null
rm -rf ./vm-tokens ./vm-config
kubectl delete namespace vm-apps istio-eastwest --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
```

## MySQL on a VM (lab `012`)

```bash
docker rm -f -v db-vm-ztunnel db-vm-mysql db-vm 2>/dev/null
rm -rf ./vm-db-tokens ./vm-db-config
kubectl delete namespace vm-db db-clients --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
```

## Uninstall Istio

```bash
helm uninstall ztunnel -n istio-system --kube-context $KUBECONTEXT_CLUSTER1
helm uninstall istiod -n istio-system --kube-context $KUBECONTEXT_CLUSTER1
helm uninstall istio-cni -n istio-system --kube-context $KUBECONTEXT_CLUSTER1
helm uninstall istio-base -n istio-system --kube-context $KUBECONTEXT_CLUSTER1
kubectl delete namespace istio-system --context $KUBECONTEXT_CLUSTER1
```

Or use `solo-istioctl` to purge:
```bash
./solo-istioctl uninstall --purge -y --context $KUBECONTEXT_CLUSTER1
```
