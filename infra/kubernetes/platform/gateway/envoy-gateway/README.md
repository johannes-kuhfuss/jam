# Envoy Gateway

Envoy Gateway is the public HTTP/gRPC edge for jam APIs.

The active configuration installs Envoy Gateway and creates a lab `Gateway` named `public-api`.

- `http` listens on `*.mam.jku.internal`
- `https` listens on `*.mam.jku.internal`
- TLS terminates with the cert-manager managed `mam-jku-internal-wildcard-tls` Secret

The lab platform exposes these operator UIs through this Gateway:

- `https://hubble.mam.jku.internal`
- `https://longhorn.mam.jku.internal`

The platform configuration also creates a stable internal service named `public-api-internal` in `envoy-gateway-system`. `scripts/dev/deploy-platform.sh` patches CoreDNS so in-cluster clients resolve `auth.mam.jku.internal` to that stable service name instead of the external L2 load-balancer address. This avoids hairpin routing problems when Envoy Gateway validates OIDC issuers from inside the cluster.

`scripts/dev/deploy-platform.sh` also copies the cert-manager local root CA into `envoy-gateway-system/jam-local-root-ca-bundle`. The `BackendTLSPolicy` for `public-api-internal` uses that bundle so Envoy Gateway can validate the ZITADEL issuer certificate during OIDC discovery.

## Operator UI Authentication

Hubble UI and Longhorn UI can be protected with route-scoped Envoy Gateway OIDC `SecurityPolicy` resources. The policies are enabled by `scripts/dev/prepare-operator-oidc.sh` after the matching client secrets are written.

Create these ZITADEL OIDC applications manually:

| UI | Type | Authentication Method | Suggested app name | Redirect URI |
| --- | --- | --- | --- | --- |
| Hubble UI | `Web` | `Code` | `hubble-ui` | `https://hubble.mam.jku.internal/oauth2/callback` |
| Longhorn UI | `Web` | `Code` | `longhorn-ui` | `https://longhorn.mam.jku.internal/oauth2/callback` |

Use the generated client IDs and client secrets from both applications, then run:

```sh
sh scripts/dev/prepare-operator-oidc.sh
./scripts/dev/deploy-platform.sh
```

The preparation script prompts for the generated client IDs and client secrets, writes SOPS-encrypted Kubernetes Secrets, updates the `SecurityPolicy` client IDs, and enables the route-scoped `SecurityPolicy` manifests.

Set the intended public Gateway IP with `spec.addresses` in `config/public-gateway.yaml`. The chosen IP must be inside the Cilium `CiliumLoadBalancerIPPool` configured in `infra/platform/cilium/l2-lab.yaml`.

Before exposing the MAM beyond the lab:

- point local/manual DNS records at the Envoy Gateway load balancer IP
- install the generated local root CA into trusted client stores
- add `HTTPRoute` resources for each public API
- apply OIDC/JWT `SecurityPolicy` resources after ZITADEL clients and secrets exist

Keep bulk media uploads out of the gateway path when possible. Use an authenticated API call to create an upload intent, return a pre-signed object-storage URL, and let the browser upload directly to object storage.
