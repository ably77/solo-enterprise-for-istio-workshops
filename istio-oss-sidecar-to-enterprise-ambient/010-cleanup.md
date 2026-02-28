# Cleanup

Remove all workshop resources from the cluster.

```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name
export MESH_NAME_CLUSTER1=cluster1    # Recommended to keep as cluster1 for POC
```

Delete HTTPRoutes and Gateways:
```bash
kubectl delete httproute -n bookinfo-frontends --all --context $KUBECONTEXT_CLUSTER1
kubectl delete gateways -n istio-system --all --context $KUBECONTEXT_CLUSTER1
```

Uninstall all Istio components via Helm:
```bash
helm uninstall ztunnel -n istio-system --kube-context $KUBECONTEXT_CLUSTER1
helm uninstall istiod -n istio-system --kube-context $KUBECONTEXT_CLUSTER1
helm uninstall istio-cni -n istio-system --kube-context $KUBECONTEXT_CLUSTER1
helm uninstall istio-base -n istio-system --kube-context $KUBECONTEXT_CLUSTER1
```

Delete all namespaces:
```bash
kubectl delete ns bookinfo-frontends bookinfo-backends egress istio-system --context $KUBECONTEXT_CLUSTER1
```
