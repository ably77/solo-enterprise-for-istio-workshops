# Cleanup

Remove all workshop resources from the cluster.

## Bookinfo application

```bash
kubectl delete namespace bookinfo-frontends bookinfo-backends --context $KUBECONTEXT_CLUSTER1
```

## Ingress gateway and routes

```bash
kubectl delete httproute bookinfo-route -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
kubectl delete gateway ingress -n istio-system --context $KUBECONTEXT_CLUSTER1 --ignore-not-found
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
