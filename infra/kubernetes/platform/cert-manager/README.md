# cert-manager

cert-manager issues local lab certificates for `*.mam.jku.internal`.

The lab uses a private PKI:

1. `jam-selfsigned` bootstraps a root CA certificate.
2. `jam-local-ca` signs workload certificates from that root.
3. `mam-jku-internal-wildcard` creates `mam-jku-internal-wildcard-tls` in `envoy-gateway-system`.

Clients must trust the generated root CA before browsers, CLI tools, or API clients accept the certificates.

Export the root CA after the certificate is ready:

```sh
kubectl get secret jam-local-root-ca \
  --namespace cert-manager \
  --template='{{ index .data "tls.crt" }}' | base64 -d > jam-local-root-ca.crt
```

Manual DNS must point the intended names at the Envoy Gateway load balancer address, for example:

```text
auth.mam.jku.internal -> <envoy-load-balancer-ip>
api.mam.jku.internal  -> <envoy-load-balancer-ip>
*.mam.jku.internal    -> <envoy-load-balancer-ip>
```
