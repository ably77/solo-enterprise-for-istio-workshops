# Cleanup

Remove all workshop resources from the cluster.

```bash
export CLUSTER1=cluster1
```

Delete HTTPRoutes and Gateways:
```bash
kubectl delete httproute -n bookinfo-frontends --all --context $CLUSTER1
kubectl delete gateways -n istio-system --all --context $CLUSTER1
```

Uninstall all Istio components via Helm:
```bash
helm uninstall ztunnel -n istio-system --kube-context $CLUSTER1
helm uninstall istiod -n istio-system --kube-context $CLUSTER1
helm uninstall istio-cni -n istio-system --kube-context $CLUSTER1
helm uninstall istio-base -n istio-system --kube-context $CLUSTER1
```

Delete all namespaces:
```bash
kubectl delete ns bookinfo-frontends bookinfo-backends egress istio-system --context $CLUSTER1
```
