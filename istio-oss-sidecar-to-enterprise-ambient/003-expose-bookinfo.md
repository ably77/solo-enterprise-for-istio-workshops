# Expose Bookinfo via Ingress Gateway

# Objectives
- Deploy an Istio Ingress Gateway using the Gateway API
- Expose the Bookinfo application via an HTTPRoute
- Validate access via the LoadBalancer address or port-forward

## Prerequisites
- This lab assumes you have completed labs `001`–`002`

Ensure the following environment variables are set:
```bash
export CLUSTER1=cluster1
```

## Deploy an Istio Ingress Gateway

Create a Gateway resource using the `istio` GatewayClass:
```bash
kubectl apply --context $CLUSTER1 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ingress
  namespace: istio-system
spec:
  infrastructure:
    parametersRef:
      group: ""
      kind: ConfigMap
      name: gw-options
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gw-options
  namespace: istio-system
data:
  service: |
    metadata:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
EOF
```

Wait for the gateway pod to be ready:
```bash
kubectl rollout status deploy/ingress-istio -n istio-system --watch --timeout=90s --context $CLUSTER1
```

Check that the gateway pod and service are running:
```bash
kubectl get pods -n istio-system --context $CLUSTER1
kubectl get svc -n istio-system --context $CLUSTER1
```

Expected output:
```
NAME                            READY   STATUS    RESTARTS   AGE
ingress-istio-<hash>            1/1     Running   0          30s
istiod-<hash>                   1/1     Running   0          10m
```

A LoadBalancer service should also be created:
```
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
ingress-istio   LoadBalancer   10.96.133.188   <address>       80:31705/TCP   30s
istiod          ClusterIP      10.96.128.33    <none>          15010/TCP,...  10m
```

> **Note:** The cloud load balancer may take a few minutes to be provisioned. If `EXTERNAL-IP` shows `<pending>`, wait and re-run `kubectl get svc` until an address is assigned.

## Expose Bookinfo via HTTPRoute

Route all traffic from the ingress gateway to the productpage service:
```bash
kubectl apply --context $CLUSTER1 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: bookinfo-route
  namespace: bookinfo-frontends
spec:
  parentRefs:
    - name: ingress
      namespace: istio-system
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
      - name: productpage
        port: 9080
EOF
```

## Validate Access

Get the external IP and navigate to the app:
```bash
SVC=$(kubectl -n istio-system get svc ingress-istio --context $CLUSTER1 --no-headers | awk '{ print $4 }')
echo http://$SVC/productpage
```

Or verify with curl:
```bash
curl http://$SVC/productpage | grep -o "<title>.*</title>"
```

### No LoadBalancer? Use Port-Forward

If your cluster does not have LoadBalancer integration (e.g. kind, minikube, or bare-metal without MetalLB), the `EXTERNAL-IP` field will remain `<pending>`. Port-forward directly to the productpage service instead:
```bash
kubectl port-forward svc/productpage -n bookinfo-frontends 9080:9080 --context $CLUSTER1
```

Navigate to http://localhost:9080/productpage or verify with curl:
```bash
curl http://localhost:9080/productpage | grep -o "<title>.*</title>"
```

## Next Steps

At this point we have completed the following objectives:
- Deployed an Istio Ingress Gateway using the Gateway API
- Exposed Bookinfo via an HTTPRoute
- Validated access via LoadBalancer or port-forward

**Phase 1 is complete.** In the next step `004` we begin the migration — upgrading in-place from OSS Istio to Solo Enterprise Istio Ambient.
