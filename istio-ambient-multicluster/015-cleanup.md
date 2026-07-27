## Cleanup

Uninstall Istio and Bookinfo application on `cluster1` and `cluster2` by running this for loop

```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name

export KUBECONTEXT_CLUSTER2=cluster2  # Replace with your actual kubectl context name
export CLUSTERS=($KUBECONTEXT_CLUSTER1 $KUBECONTEXT_CLUSTER2)
```

> **Completed the bonus lab `014-add-a-third-cluster.md`?** Also export `KUBECONTEXT_CLUSTER3` and add it to the array before running the loop below:
> ```bash
> export KUBECONTEXT_CLUSTER3=cluster3  # Replace with your actual kubectl context name
> CLUSTERS+=($KUBECONTEXT_CLUSTER3)
> ```

The loop below covers every namespace and Helm release the workshop creates, including the ones added by
the optional labs. `--ignore-not-found` keeps it quiet for labs you skipped. The two `kubectl get crd`
guards cover a different case: `--ignore-not-found` forgives a missing *resource* but still errors on a
missing *CRD*, which is what you hit if you rerun this teardown after removing the CRDs below.

```bash
for CONTEXT in "${CLUSTERS[@]}"; do
  echo "Cleaning up $CONTEXT..."

  # Routes and gateways
  if kubectl get crd gateways.gateway.networking.k8s.io --context $CONTEXT &>/dev/null; then
    kubectl delete httproute -n bookinfo-frontends --all --context $CONTEXT --ignore-not-found
    kubectl delete gateways -n istio-gateways --all --context $CONTEXT --ignore-not-found
    kubectl delete gateways -n istio-system --all --context $CONTEXT --ignore-not-found
  fi

  # Segments from labs 007/008
  if kubectl get crd segments.admin.solo.io --context $CONTEXT &>/dev/null; then
    kubectl delete segments -n istio-system --all --context $CONTEXT --ignore-not-found
  fi
  kubectl label namespace istio-system admin.solo.io/segment- --context $CONTEXT 2>/dev/null

  # Solo Management UI (lab 013): management on the mgmt cluster, relay on the others
  helm uninstall management -n kagent --kube-context $CONTEXT --ignore-not-found
  helm uninstall relay -n solo-enterprise --kube-context $CONTEXT --ignore-not-found

  # Peering (lab 006 Option B, extended in lab 014)
  helm uninstall peering-remote -n istio-gateways --kube-context $CONTEXT --ignore-not-found

  # Istio
  helm uninstall ztunnel -n istio-system --kube-context $CONTEXT --ignore-not-found
  helm uninstall istiod -n istio-system --kube-context $CONTEXT --ignore-not-found
  helm uninstall istio-cni -n istio-system --kube-context $CONTEXT --ignore-not-found
  helm uninstall istio-base -n istio-system --kube-context $CONTEXT --ignore-not-found

  # Namespaces: bookinfo, istio, egress (lab 012), kagent and solo-enterprise (lab 013)
  kubectl delete ns bookinfo-frontends bookinfo-backends istio-gateways istio-system \
    egress kagent solo-enterprise --context $CONTEXT --ignore-not-found
done
```

Confirm nothing is left:

```bash
for CONTEXT in "${CLUSTERS[@]}"; do
  echo "--- $CONTEXT ---"
  kubectl get ns --context $CONTEXT --no-headers | grep -E "bookinfo|istio|egress|kagent|solo-enterprise"
  helm list -A --kube-context $CONTEXT
done
```

Both commands should return nothing.

## Istio CRDs

`helm uninstall istio-base` leaves the Istio and Gateway API CRDs in place, which is deliberate: removing
a CRD deletes every custom resource of that kind across the cluster. Leave them if you plan to reinstall.
To remove them on a cluster you are done with:

```bash
for CONTEXT in "${CLUSTERS[@]}"; do
  kubectl get crd --context $CONTEXT -o name \
    | grep -E "istio\.io|admin\.solo\.io|gateway\.networking\.k8s\.io" \
    | xargs -r kubectl delete --context $CONTEXT
done
```

## Local files

Lab `002` writes two files into this directory. Remove them once you are finished:

```bash
rm -f shared-root-trust-secret.yaml solo-istioctl
```
