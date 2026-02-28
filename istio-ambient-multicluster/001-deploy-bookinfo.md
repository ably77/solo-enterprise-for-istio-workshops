# Deploy Bookinfo Application

# Objectives
- Deploy the bookinfo sample application across two namespaces on cluster1 and cluster2
- Validate the application is accessible via port-forward

![](../images/deploy-bookinfo-1.png)

## Prerequisites
- This lab assumes you have read through and completed any setup from the `000` labs

Ensure the following environment variables are set from the previous labs:
```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name
export MESH_NAME_CLUSTER1=cluster1    # Recommended to keep as cluster1 for POC

export KUBECONTEXT_CLUSTER2=cluster2  # Replace with your actual kubectl context name
export MESH_NAME_CLUSTER2=cluster2    # Recommended to keep as cluster2 for POC
```

## Deploy Bookinfo on cluster1

Deploy bookinfo frontends in bookinfo-frontends namespace
```bash
kubectl apply -f bookinfo/bookinfo-frontends.yaml --context $KUBECONTEXT_CLUSTER1
```

Deploy bookinfo backends in bookinfo-backends namespace
```bash
kubectl apply -f bookinfo/bookinfo-backends.yaml --context $KUBECONTEXT_CLUSTER1
```

Wait for the applications to be deployed
```bash
for deploy in $(kubectl get deploy -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Waiting for frontend deployment '$deploy' to be ready in $KUBECONTEXT_CLUSTER1..."
  kubectl rollout status deploy/"$deploy" -n bookinfo-frontends --watch --timeout=90s --context $KUBECONTEXT_CLUSTER1
  done

for deploy in $(kubectl get deploy -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Waiting for backend deployment '$deploy' to be ready in $KUBECONTEXT_CLUSTER1..."
  kubectl rollout status deploy/"$deploy" -n bookinfo-backends --watch --timeout=90s --context $KUBECONTEXT_CLUSTER1
  done
```

Update the reviews service to display which cluster it is coming from
```bash
kubectl --context $KUBECONTEXT_CLUSTER1 -n bookinfo-backends set env deploy/reviews-v1 CLUSTER_NAME=$MESH_NAME_CLUSTER1
kubectl --context $KUBECONTEXT_CLUSTER1 -n bookinfo-backends set env deploy/reviews-v2 CLUSTER_NAME=$MESH_NAME_CLUSTER1
kubectl --context $KUBECONTEXT_CLUSTER1 -n bookinfo-backends set env deploy/reviews-v3 CLUSTER_NAME=$MESH_NAME_CLUSTER1
```

Port forward to productpage in bookinfo-frontends namespace to validate application is working
```bash
kubectl port-forward svc/productpage -n bookinfo-frontends 9080:9080 --context $KUBECONTEXT_CLUSTER1
```
Navigate to http://localhost:9080/productpage

## Deploy Bookinfo on cluster2

Deploy bookinfo frontends in bookinfo-frontends namespace
```bash
kubectl apply -f bookinfo/bookinfo-frontends.yaml --context $KUBECONTEXT_CLUSTER2
```

Deploy bookinfo backends in bookinfo-backends namespace
```bash
kubectl apply -f bookinfo/bookinfo-backends.yaml --context $KUBECONTEXT_CLUSTER2
```

Wait for the applications to be deployed
```bash
for deploy in $(kubectl get deploy -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER2 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Waiting for frontend deployment '$deploy' to be ready in $KUBECONTEXT_CLUSTER2..."
  kubectl rollout status deploy/"$deploy" -n bookinfo-frontends --watch --timeout=90s --context $KUBECONTEXT_CLUSTER2
  done

for deploy in $(kubectl get deploy -n bookinfo-backends --context $KUBECONTEXT_CLUSTER2 -o jsonpath='{.items[*].metadata.name}'); do
  echo "Waiting for backend deployment '$deploy' to be ready in $KUBECONTEXT_CLUSTER2..."
  kubectl rollout status deploy/"$deploy" -n bookinfo-backends --watch --timeout=90s --context $KUBECONTEXT_CLUSTER2
  done
```

Update the reviews service to display which cluster it is coming from
```bash
kubectl --context $KUBECONTEXT_CLUSTER2 -n bookinfo-backends set env deploy/reviews-v1 CLUSTER_NAME=$MESH_NAME_CLUSTER2
kubectl --context $KUBECONTEXT_CLUSTER2 -n bookinfo-backends set env deploy/reviews-v2 CLUSTER_NAME=$MESH_NAME_CLUSTER2
kubectl --context $KUBECONTEXT_CLUSTER2 -n bookinfo-backends set env deploy/reviews-v3 CLUSTER_NAME=$MESH_NAME_CLUSTER2
```

Port forward to productpage in bookinfo-frontends namespace to validate application is working
```bash
kubectl port-forward svc/productpage -n bookinfo-frontends 9080:9080 --context $KUBECONTEXT_CLUSTER2
```
Navigate to http://localhost:9080/productpage

## Next Steps
At this point we have completed the following objectives
- Deployed the bookinfo sample application across two namespaces on cluster1 and cluster2
- Validated the application is accessible via port-forward

In the next step `002` we will install Istio on cluster1
