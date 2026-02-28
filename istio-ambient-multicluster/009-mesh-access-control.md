# Enforce Mesh Access Control Policies

# Objectives
- Apply a deny-all authorization policy to establish a zero-trust baseline
- Incrementally allow traffic between bookinfo services using Istio AuthorizationPolicy
- Validate each policy change using the browser or curl
- Observe policy enforcement in ztunnel logs

## Prerequisites
- This lab assumes you have completed setup from labs `000-004`
- Setup from lab `005` is optional but recommended

Ensure the following environment variables are set:
```bash
export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name
export MESH_NAME_CLUSTER1=cluster1    # Recommended to keep as cluster1 for POC
```

## Access Control
Bookinfo is a great application to demonstrate access control because it has distinct frontend and backend services, allowing fine-grained policies to be applied and tested across service boundaries.

Check to see that the application has been deployed
```bash
kubectl get pods -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1
kubectl get pods -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1
```

Set the `SVC` variable to the ingress gateway LoadBalancer address
```bash
SVC=$(kubectl -n istio-system get svc ingress-istio --context $KUBECONTEXT_CLUSTER1 --no-headers | awk '{ print $4 }')
```

> **No LoadBalancer?** If you are using port-forward, set `SVC=localhost:9080` instead and keep the port-forward to `svc/productpage` from lab 005 running in a separate terminal.

Navigate to the bookinfo application in your browser
```bash
echo http://$SVC/productpage
```

Or verify with curl
```bash
curl -s http://$SVC/productpage | grep -A 10 "Simple Bookstore App"
```

Throughout this lab you can either refresh the browser or use curl to validate each policy change

### Configure deny-all auth policy
Apply deny all auth policy to both bookinfo-frontends and bookinfo-backends
```bash
cat auth-policy/allow-nothing.yaml
echo
kubectl apply -f auth-policy/allow-nothing.yaml --context $KUBECONTEXT_CLUSTER1
```

If you refresh the bookinfo page in the browser you should now see `upstream connect error or disconnect/reset before headers. reset reason: connection termination`

or using curl
```bash
curl -s http://$SVC/productpage
```

Take a look at the `ztunnel` logs to see the rejection
```bash
kubectl logs -n istio-system -l app=ztunnel --context $KUBECONTEXT_CLUSTER1 -f --prefix
```

![](../images/auth-pol-1.png)

### Allow access from istio ingress to productpage
Allow Istio ingress to access productpage
```bash
cat auth-policy/productpage-auth.yaml
echo
kubectl apply -f auth-policy/productpage-auth.yaml --context $KUBECONTEXT_CLUSTER1
```
Refresh the application in the browser, now you should be able to access the productpage app, but notice that the details, ratings, and reviews applications are unavailable

or using curl
```bash
curl -s http://$SVC/productpage | grep -A 10 "Simple Bookstore App"
curl -s http://$SVC/productpage | grep -A 10 details
curl -s http://$SVC/productpage | grep -A 10 reviews
```

Take a look at the `ztunnel` logs, this time you will see a successful connection from the ingress gateway to productpage

But notice that we observe a `401 Unauthorized` for the connnection from productpage to reviews, ratings, and details
```bash
kubectl logs -n istio-system -l app=ztunnel --context $KUBECONTEXT_CLUSTER1 -f --prefix
```

![](../images/auth-pol-2.png)

### Allow access from productpage to details
Allow productpage to access details
```bash
cat auth-policy/details-auth.yaml
echo
kubectl apply -f auth-policy/details-auth.yaml --context $KUBECONTEXT_CLUSTER1
```
Refresh the application in the browser, now you should be able to access the productpage app and details but ratings and reviews applications are unavailable

or using curl
```bash
curl -s http://$SVC/productpage | grep -A 10 "Simple Bookstore App"
curl -s http://$SVC/productpage | grep -A 10 details
curl -s http://$SVC/productpage | grep -A 10 reviews
```

![](../images/auth-pol-3.png)

### Allow access from productpage to reviews
Allow productpage to access reviews
```bash
cat auth-policy/reviews-auth.yaml
echo
kubectl apply -f auth-policy/reviews-auth.yaml --context $KUBECONTEXT_CLUSTER1
```
Refresh the application in the browser, now you should be able to access the productpage app, details, and reviews, but not the ratings app (no stars available)

or using curl
```bash
curl -s http://$SVC/productpage | grep -A 10 "Simple Bookstore App"
curl -s http://$SVC/productpage | grep -A 10 details
curl -s http://$SVC/productpage | grep -A 10 reviews
```

![](../images/auth-pol-4.png)

### Allow access from reviews to ratings
Allow reviews to access ratings
```bash
cat auth-policy/ratings-auth.yaml
echo
kubectl apply -f auth-policy/ratings-auth.yaml --context $KUBECONTEXT_CLUSTER1
```
Now the application should be fully accessible, and you have established full zero-trust using Istio authorization policies!

or using curl
```bash
curl -s http://$SVC/productpage | grep -A 10 "Simple Bookstore App"
curl -s http://$SVC/productpage | grep -A 10 details
curl -s http://$SVC/productpage | grep -A 10 reviews
```

![](../images/auth-pol-5.png)

## Cleanup

Remove components
```bash
kubectl delete authorizationpolicies --all -n bookinfo-frontends --context $KUBECONTEXT_CLUSTER1
kubectl delete authorizationpolicies --all -n bookinfo-backends --context $KUBECONTEXT_CLUSTER1
```

## Next Steps
At this point we have completed the following objectives
- Enforced zero-trust access control policies across bookinfo services
- Validated authorization policies using Istio AuthorizationPolicy

In the next step `010` we will configure L7 traffic management with waypoints
