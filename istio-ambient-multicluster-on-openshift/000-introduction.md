# Openshift Ambient Workshop

# Objectives
- Deploy Istio on Openshift with Helm based install
- Deploy sample microservices on two different namespaces (bookinfo app)
- Install Istio Ambient Mesh
- Enable Ambient Mesh for app namespaces (bookinfo-frontends and bookinfo-backends)
- Setup Ingress Gateway to access the bookinfo frontend (productpage)
- Link the two clusters
- Configure a globally available service using labels (productpage)
- Reconfigure ingress to global service hostname (*.<namespace>.mesh.internal)
- Establish zero-trust security using mesh access control policies
- Egress Control
- Install Gloo Mesh control plane for multicluster UI

# Use Cases
- Zero Trust (mTLS)
- Ingress
- Observability
- Multi-cluster routing
- Global service discovery
- High Availability
- Failover

## Validated on
- OpenShift 4.16.0 - 4.18.18 (latest)
- Istio 1.26.1-solo
- Gloo Platform 2.9.1

# Application Diagram
![](images/high-level-architecture-1.png)

## License Key Details
Gloo Trial License Expires:
```
```