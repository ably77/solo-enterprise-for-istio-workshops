# Egress with Waypoint

# Objectives
- Deploy a shared egress waypoint in a dedicated `egress` namespace
- Route outbound traffic to an external service through the waypoint
- Enable access logging on the egress waypoint
- Enforce egress authorization policies to restrict allowed paths and source principals

![](../images/egress-1.png)

## Prerequisites
- This lab assumes you have completed labs `000`–`005`
- Bookinfo namespaces are enrolled in ambient mesh (pods show `1/1 READY`, HBONE protocol)

Ensure the following environment variables are set:
```bash
export CLUSTER1=cluster1
```

## Deploy the Egress Waypoint

Create a dedicated `egress` namespace and deploy a shared waypoint. This waypoint serves as a centralized control point for outbound traffic to external services:

```bash
kubectl apply --context $CLUSTER1 -f - <<EOF
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

Wait for the waypoint to be ready:
```bash
kubectl rollout status deployment/egress-waypoint -n egress --context $CLUSTER1
```

Verify the egress waypoint pod is running:
```bash
kubectl get pods -n egress --context $CLUSTER1
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE
egress-waypoint-<hash>             1/1     Running   0          8s
```

Enable access logging on the egress waypoint:
```bash
kubectl apply --context $CLUSTER1 -f - <<EOF
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

## Route External Traffic Through the Waypoint

Create a `ServiceEntry` to represent the external service `jsonplaceholder.typicode.com`. The `istio.io/use-waypoint` label on the ServiceEntry instructs ztunnel to route traffic destined for this host through the egress waypoint:

```bash
kubectl apply --context $CLUSTER1 -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
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

Open a second terminal and tail the egress waypoint logs:
```bash
kubectl logs -n egress deploy/egress-waypoint -f --context $CLUSTER1
```

In your original terminal, exec into `reviews-v1` and send a request to the external service:
```bash
kubectl exec deploy/reviews-v1 -n bookinfo-backends --context $CLUSTER1 -- \
  curl -sI jsonplaceholder.typicode.com/posts | grep envoy
```

Expected output — Envoy response headers confirm traffic passed through the waypoint:
```
server: istio-envoy
x-envoy-upstream-service-time: 255
x-envoy-decorator-operation: :80/*
```

In the waypoint log output you should see an access log entry for the request:
```
[2025-05-22T01:52:13.224Z] "HEAD /posts HTTP/1.1" 200 - via_upstream - "-" 0 0 206 206 "-" "curl/7.81.0" "f400f1de-..." "jsonplaceholder.typicode.com" "104.21.48.1:80" inbound-vip|80|http|jsonplaceholder.typicode.com ...
```

## Enforce Egress Policy Controls

Apply an egress authorization policy that restricts access to `jsonplaceholder.typicode.com` — only the `reviews` service account may make `GET` requests, and only to the `/posts` path:

```bash
cat auth-policy/egress-auth.yaml
echo
kubectl apply -f auth-policy/egress-auth.yaml --context $CLUSTER1
```

Verify an allowed request succeeds — `reviews-v1` calling `/posts` with `GET`:
```bash
kubectl exec deploy/reviews-v1 -n bookinfo-backends --context $CLUSTER1 -- \
  curl jsonplaceholder.typicode.com/posts
```

This request should succeed (`200 OK`).

Now try the `/comments` path, which is not in the allowed paths:
```bash
kubectl exec deploy/reviews-v1 -n bookinfo-backends --context $CLUSTER1 -- \
  curl jsonplaceholder.typicode.com/comments
```

You should see `RBAC: access denied` — the egress policy restricts access to `/posts` only.

Try from the `ratings` service, which is not an allowed source principal:
```bash
kubectl exec deploy/ratings-v1 -n bookinfo-backends --context $CLUSTER1 -- \
  curl jsonplaceholder.typicode.com/posts
```

You should also see `RBAC: access denied` — the policy allows only `bookinfo-reviews` as the source principal.

Check the egress waypoint logs to see the RBAC deny entries:
```bash
kubectl logs -n egress deploy/egress-waypoint --context $CLUSTER1 | grep rbac
```

Expected log entry for a denied request:
```
[2025-05-22T01:57:28.209Z] "GET /posts HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] ...
```

## Cleanup

```bash
kubectl delete authorizationpolicy jsonplaceholder-egress -n egress --context $CLUSTER1 --ignore-not-found
kubectl delete serviceentry jsonplaceholder.typicode.com -n egress --context $CLUSTER1 --ignore-not-found
kubectl delete telemetry enable-access-logging -n egress --context $CLUSTER1 --ignore-not-found
kubectl delete gateway egress-waypoint -n egress --context $CLUSTER1 --ignore-not-found
kubectl delete namespace egress --context $CLUSTER1 --ignore-not-found
```

## Next Steps

At this point we have completed the following objectives:
- Deployed a shared egress waypoint in a dedicated `egress` namespace
- Routed outbound traffic to an external service through the waypoint
- Confirmed waypoint interception via Envoy response headers and access logs
- Enforced egress authorization policies by path and source principal

In the next step `010` we will clean up the workshop environment.
