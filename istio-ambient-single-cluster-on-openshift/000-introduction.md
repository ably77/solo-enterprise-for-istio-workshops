# Istio Ambient Single Cluster Workshop — OpenShift

# Objectives
- Deploy Solo Istio Ambient on OpenShift with a Helm-based install
- Deploy the Bookinfo sample application across two namespaces
- Enroll workloads in the Ambient Mesh
- Expose the Bookinfo frontend via an Ingress Gateway
- Control egress traffic through a dedicated egress waypoint
- Observe L4 and L7 mesh metrics

# Use Cases
- Zero Trust (mTLS)
- Ingress
- Egress Control
- Observability

## Validated on
- OpenShift 4.16.0 - 4.19.30 (latest)
- Istio 1.30.2-solo

## License Key Details
This workshop requires a Solo Trial License Key, exported as `SOLO_TRIAL_LICENSE_KEY` in lab `002`.
Contact your Solo.io account team if you need one. Check the expiry before you start:

```bash
for SEG in $(echo "$SOLO_TRIAL_LICENSE_KEY" | tr '.' ' '); do
  case $(( ${#SEG} % 4 )) in 2) SEG="${SEG}==" ;; 3) SEG="${SEG}=" ;; esac
  EXP=$(printf '%s' "$SEG" | tr '_-' '/+' | base64 -d 2>/dev/null \
        | LC_ALL=C sed -n 's/.*"exp":\([0-9]*\).*/\1/p')
  [ -n "$EXP" ] && break
done

if [ -z "$EXP" ]; then
  echo "Could not read an expiry from SOLO_TRIAL_LICENSE_KEY. Is it set?"
else
  date -d "@$EXP" 2>/dev/null || date -r "$EXP"
fi
```
