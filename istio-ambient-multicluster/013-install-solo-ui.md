# Install the Solo Management UI

# Objectives
- Install the Solo Management UI on `cluster1` with the mesh product view
- Install the Solo Enterprise relay on `cluster2` to tunnel telemetry back to the management UI through Istio Ambient
- Access the Solo Management UI to inspect the multi-cluster mesh

![](../images/solo-ui-1.png)

![](../images/solo-ui-2.png)

![](../images/solo-ui-3.png)

## Prerequisites
- This lab assumes you have completed setup from labs `000-006`. Lab `006` is load-bearing — the relay reaches the management UI via the `*.mesh.internal` cross-cluster hostnames configured there.

## Set environment variables

```bash
export SOLO_MANAGEMENT_UI_VERSION=0.4.1-2026-05-14-main-6fb46ef2
export SOLO_MANAGEMENT_UI_OCI_REPO=us-docker.pkg.dev/developers-369321/solo-enterprise-public-nonprod

export KUBECONTEXT_CLUSTER1=cluster1  # Replace with your actual kubectl context name
export KUBECONTEXT_CLUSTER2=cluster2  # Replace with your actual kubectl context name
```

This lab assumes `SOLO_TRIAL_LICENSE_KEY` is already exported from earlier in the workshop.

## Install the Solo Management UI on cluster1

Install the `management` chart. This installs ClickHouse (telemetry storage), the Solo Enterprise telemetry collector, and the Solo Enterprise UI with the **mesh** product view enabled. The chart enables Istio ambient integration by default — it automatically labels its own pods with `istio.io/dataplane-mode=ambient` and labels the `solo-enterprise-ui` and `solo-enterprise-telemetry-gateway` services with `solo.io/service-scope=global`, so the workload cluster's relay can reach them over the ambient mesh via `*.mesh.internal`.

> **Private registry users:** Each component below includes a commented-out `image` override block. Uncomment and update the `registry`, `repository`, and `tag` fields to point to your private registry before running this command. For most users a single `global.image` override is sufficient — the per-component blocks are provided for finer-grained control.

```bash
helm upgrade --install management \
  oci://${SOLO_MANAGEMENT_UI_OCI_REPO}/charts/management \
  --version ${SOLO_MANAGEMENT_UI_VERSION} \
  --namespace kagent \
  --create-namespace \
  --kube-context $KUBECONTEXT_CLUSTER1 \
  --no-hooks \
  -f -<<EOF
cluster: "${KUBECONTEXT_CLUSTER1}"
# override (global fallback for all solo-owned images)
#global:
#  image:
#    registry: us-docker.pkg.dev/solo-public
#    repository: solo-enterprise
#    tag: ${SOLO_MANAGEMENT_UI_VERSION}
service:
  type: ClusterIP
products:
  kagent:
    enabled: false
  agentgateway:
    enabled: false
  mesh:
    enabled: true
  agentregistry:
    enabled: false
licensing:
  licenseKey: "${SOLO_TRIAL_LICENSE_KEY}"
# override (tunnel server image)
#tunnelserver:
#  registry: us-docker.pkg.dev/solo-public
#  repository: solo-enterprise
#  name: solo-enterprise-tunnel-server
#  tag: ${SOLO_MANAGEMENT_UI_VERSION}
# override (UI images)
#ui:
#  backend:
#    registry: us-docker.pkg.dev/solo-public
#    repository: solo-enterprise
#    name: solo-enterprise-ui-backend
#  frontend:
#    registry: us-docker.pkg.dev/solo-public
#    repository: solo-enterprise
#    name: solo-enterprise-ui-frontend
# override (telemetry collector image)
#telemetry:
#  image:
#    registry: docker.io
#    repository: otel
#    name: opentelemetry-collector-contrib
#    tag: 0.150.1
EOF
```

Wait for the management workloads to be ready:

```bash
kubectl rollout status statefulset/management-clickhouse-shard0 \
  -n kagent --context $KUBECONTEXT_CLUSTER1 --timeout=300s
kubectl rollout status statefulset/solo-enterprise-telemetry-collector \
  -n kagent --context $KUBECONTEXT_CLUSTER1 --timeout=300s
kubectl rollout status deployment/solo-enterprise-ui \
  -n kagent --context $KUBECONTEXT_CLUSTER1 --timeout=300s
```

Verify the pods on cluster1:

```bash
kubectl get pods -n kagent --context $KUBECONTEXT_CLUSTER1
```

The output should look similar to:

```
NAME                                            READY   STATUS    RESTARTS   AGE
management-clickhouse-shard0-0                  1/1     Running   0          90s
solo-enterprise-telemetry-collector-0           1/1     Running   0          90s
solo-enterprise-ui-7c5f8d6b4d-abc12             1/1     Running   0          90s
```

Confirm the chart auto-applied the cross-cluster service labels — the relay on cluster2 relies on these:

```bash
kubectl get svc solo-enterprise-ui solo-enterprise-telemetry-gateway \
  -n kagent --context $KUBECONTEXT_CLUSTER1 \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.solo\.io/service-scope}{"\n"}{end}'
```

Both services should report `global`.

## Install the Solo Enterprise relay on cluster2

The relay is a small workload that runs on every cluster *other than* the management cluster. It forwards telemetry from the workload cluster back to the management cluster's UI through the ambient mesh — no LoadBalancer, no relay tokens, and no external endpoints required.

> **Private registry users:** Uncomment the override block below and point it at your private registry before running.

```bash
helm upgrade --install relay \
  oci://${SOLO_MANAGEMENT_UI_OCI_REPO}/charts/relay \
  --version ${SOLO_MANAGEMENT_UI_VERSION} \
  --namespace solo-enterprise \
  --create-namespace \
  --kube-context $KUBECONTEXT_CLUSTER2 \
  -f -<<EOF
cluster: "${KUBECONTEXT_CLUSTER2}"
# override (global fallback for all solo-owned images)
#global:
#  image:
#    registry: us-docker.pkg.dev/solo-public
#    repository: solo-enterprise
#    tag: ${SOLO_MANAGEMENT_UI_VERSION}
tunnel:
  fqdn: solo-enterprise-ui.kagent.mesh.internal
  port: 9000
telemetry:
  fqdn: solo-enterprise-telemetry-gateway.kagent.mesh.internal
# override (telemetry collector image)
#  image:
#    registry: docker.io
#    repository: otel
#    name: opentelemetry-collector-contrib
#    tag: 0.150.1
EOF
```

Wait for the relay rollout:

```bash
kubectl rollout status deployment/solo-enterprise-relay \
  -n solo-enterprise --context $KUBECONTEXT_CLUSTER2 --timeout=180s
```

## Access the Solo Management UI

Port-forward the UI service from cluster1:

```bash
kubectl port-forward svc/solo-enterprise-ui -n kagent 8090:80 --context $KUBECONTEXT_CLUSTER1
```

Navigate to `http://localhost:8090`. The Mesh view should show both `cluster1` and `cluster2` along with the bookinfo workloads from earlier labs.

# Uninstall

```bash
helm uninstall relay -n solo-enterprise --kube-context $KUBECONTEXT_CLUSTER2
helm uninstall management -n kagent --kube-context $KUBECONTEXT_CLUSTER1

kubectl delete ns solo-enterprise --context $KUBECONTEXT_CLUSTER2
kubectl delete ns kagent --context $KUBECONTEXT_CLUSTER1
```

## Congratulations!

You have completed the workshop! You have successfully:
- Deployed the bookinfo application across two clusters
- Installed Istio Ambient Mesh on both clusters
- Enrolled workloads into the mesh and validated mTLS with ztunnel
- Exposed the bookinfo application via an Ingress Gateway
- Configured multicluster connectivity and failover
- Isolated namespaces across clusters with Segments
- Enforced zero-trust access control policies
- Configured egress with a waypoint
- Installed the Solo Management UI for cross-cluster mesh visibility

If you would like to clean up all workshop resources, see `014` for cleanup instructions.
