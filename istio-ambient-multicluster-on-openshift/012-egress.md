# Egress with Waypoint

# Objectives
- Deploy a shared egress waypoint in a dedicated `egress` namespace
- Route outbound traffic to an external service through the waypoint
- Enable access logging on the egress waypoint
- Enforce egress authorization policies to restrict allowed paths and source principals

![](../images/egress-1.png)

### Prerequisites
This lab assumes that you have completed the setup in `010`

### Set environment variables
In this workshop, you can use your preferred cluster context. To set it, run the following command, replacing cluster1 with your desired context name
```bash
export CLUSTER1=cluster1
```

Next, we'll create a dedicated `egress` namespace and deploy a shared Waypoint. This Waypoint will serve as a centralized control point for outbound traffic from various namespaces.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/dataplane-mode: ambient
    istio.io/use-waypoint: egress-waypoint
  name: egress
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: egress-waypoint
  namespace: egress
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
```

Wait for the Waypoint deployment to be fully operational before proceeding.

```bash
kubectl -n egress rollout status deployment/egress-waypoint --context ${CLUSTER1}
```

We can see that the egress waypoint that we have created for the cluster has been deployed
```
% kubectl get pods -n egress --context ${CLUSTER1}
NAME                               READY   STATUS    RESTARTS   AGE
egress-waypoint-54dbfd59bd-sqwd9   1/1     Running   0          8s
```

Configure gateway access logging for egress waypoint
```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: enable-access-logging
  namespace: egress
spec:
  targetRefs:
  - kind: Gateway
    group: gateway.networking.k8s.io
    name: egress-waypoint
  accessLogging:
    - providers:
      - name: envoy
EOF
```

Enforce traffic to external services
Next, create a Service Entry to represent the external service 'jsonplaceholder.typicode.com' and by setting the labels `istio.io/use-waypoint` and `istio.io/use-waypoint-namespace` we configure traffic targeted at this service entry to be routed through the shared egress waypoint.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  annotations:
  labels:
    istio.io/use-waypoint: egress-waypoint
  name: jsonplaceholder.typicode.com
  namespace: egress
spec:
  hosts:
  - jsonplaceholder.typicode.com
  ports:
  - name: http
    number: 80
    protocol: HTTP
  resolution: DNS
EOF
```

To confirm that traffic is correctly flowing through the Waypoint, send a request from `reviews-v1` to the external service and look for Envoy-specific headers in the response. These headers indicate that the traffic has been processed by the Waypoint.

We can confirm that traffic intended for jsonplaceholder.typicode.com is intercepted by our egress waypoint by looking at the logs of the egress waypoint that we just deployed
```bash
kubectl logs -n egress deploy/egress-waypoint -f --context ${CLUSTER1}
```

Exec into `reviews-v1` app and curl jsonplaceholder.typicode.com
```shell
kubectl exec deploy/reviews-v1 -n bookinfo-backends --context ${CLUSTER1} -- curl -sI jsonplaceholder.typicode.com/posts | grep envoy
```

```http,nocopy
server: istio-envoy
x-envoy-upstream-service-time: 255
x-envoy-decorator-operation: :80/*
```

The presence of Envoy headers in the response confirms that our traffic is being routed through the Waypoint as intended.

We should see access logs that our traffic is being routed through our waypoint on each request
```
[2025-05-22T01:52:13.224Z] "HEAD /posts HTTP/1.1" 200 - via_upstream - "-" 0 0 206 206 "-" "curl/7.81.0" "f400f1de-1c70-4b36-adab-65681447639a" "jsonplaceholder.typicode.com" "104.21.48.1:80" inbound-vip|80|http|jsonplaceholder.typicode.com 10.42.0.15:36618 240.240.0.4:80 10.42.0.9:41320 - default
```

## Enforce Egress Policy Controls
Apply egress auth policy to allow reviews source principal to talk to the http://jsonplaceholder.typicode.com public service using the `GET` method and restricted to the `/posts` path
```bash
cat auth-policy/egress-auth.yaml
echo
kubectl apply -f auth-policy/egress-auth.yaml --context ${CLUSTER1}
```

Exec into `reviews-v1` app and curl jsonplaceholder.typicode.com/posts
```shell
kubectl exec -it deploy/reviews-v1 -n bookinfo-backends --context ${CLUSTER1} -- curl jsonplaceholder.typicode.com/posts
```
This request should succeed

Now try the /comments path instead
```shell
kubectl exec -it deploy/reviews-v1 -n bookinfo-backends --context ${CLUSTER1} -- curl jsonplaceholder.typicode.com/comments
```
You should now see `RBAC: access denied` due to the egress policy that only allows the `/posts` path

And lastly, try again from the ratings application
```shell
kubectl exec -it deploy/ratings-v1 -n bookinfo-backends --context ${CLUSTER1} -- curl jsonplaceholder.typicode.com/posts
```
You should also see `RBAC: access denied` due to the egress policy because it only allows requests from the source principal `cluster.local/ns/bookinfo-backends/sa/bookinfo-reviews`

Check the egress gateway logs to see the RBAC deny log
```
[2025-05-22T01:57:28.209Z] "GET /posts HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "-" "curl/7.88.1" "e887264c-2da9-49af-b1ad-ca8c97443ffd" "jsonplaceholder.typicode.com" "-" inbound-vip|80|http|jsonplaceholder.typicode.com - 240.240.0.4:80 10.42.0.6:39382 - default
```

Here we have demonstrated how to set up an egress gateway, force traffic through it, and enforce policies on egress traffic.

## Cleanup

Remove components
```bash
kubectl delete authorizationpolicies -n bookinfo-frontends --all --context ${CLUSTER1}
kubectl delete authorizationpolicies -n bookinfo-backends --all --context ${CLUSTER1}
kubectl delete serviceentry --all -n egress --context ${CLUSTER1}
kubectl delete telemetry enable-access-logging -n egress --context ${CLUSTER1}
kubectl delete gateway egress-waypoint -n egress --context ${CLUSTER1}
kubectl delete namespace egress --context ${CLUSTER1}

## Next Steps
At this point we have completed the following objectives
- Configured an egress gateway using a waypoint
- Enforced egress policies to control outbound traffic

In the next step `013` we will deploy the Gloo Mesh control plane
```