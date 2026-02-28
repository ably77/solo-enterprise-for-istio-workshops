## Cleanup

Uninstall Istio and Bookinfo application on `cluster1` and `cluster2` by running this for loop

```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name

export KUBECONTEXT_CLUSTER2=cluster2  # Replace with your actual kubectl context name
export CLUSTERS=($KUBECONTEXT_CLUSTER1 $KUBECONTEXT_CLUSTER2)
```

```bash
for CONTEXT in "${CLUSTERS[@]}"; do
  echo "Cleaning up $CONTEXT..."
  kubectl delete httproute -n bookinfo-frontends --all --context $CONTEXT
  kubectl delete gateways -n istio-gateways --all --context $CONTEXT
  kubectl delete gateways -n istio-system --all --context $CONTEXT
  helm uninstall ztunnel -n istio-system --kube-context $CONTEXT
  helm uninstall istiod -n istio-system --kube-context $CONTEXT
  helm uninstall istio-cni -n istio-system --kube-context $CONTEXT
  helm uninstall istio-base -n istio-system --kube-context $CONTEXT
  kubectl delete ns bookinfo-frontends bookinfo-backends istio-gateways istio-system --context $CONTEXT
done
```
