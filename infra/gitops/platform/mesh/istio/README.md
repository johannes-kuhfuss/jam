# Istio Ambient Mesh

Istio ambient mode provides service-to-service mTLS and workload identity without injecting sidecars into every pod.

The install is split into ordered Flux paths:

- `base`: Istio CRDs
- `control-plane`: `istiod`
- `cni`: Istio CNI for ambient traffic redirection
- `ztunnel`: node-level ambient data plane

Application namespaces should opt in with:

```yaml
metadata:
  labels:
    istio.io/dataplane-mode: ambient
```

After a namespace is enrolled, add namespace-scoped `PeerAuthentication` and `AuthorizationPolicy` resources deliberately. Do not apply global strict policies before every required workload path has been tested.
