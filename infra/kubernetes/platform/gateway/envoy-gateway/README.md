# Envoy Gateway

Envoy Gateway is the public HTTP/gRPC edge for jam APIs.

The active configuration installs Envoy Gateway and creates a lab `Gateway` named `public-api`.

- `http` listens on `*.mam.jku.internal`
- `https` listens on `*.mam.jku.internal`
- TLS terminates with the cert-manager managed `mam-jku-internal-wildcard-tls` Secret

The lab platform exposes these operator UIs through this Gateway:

- `https://hubble.mam.jku.internal`
- `https://longhorn.mam.jku.internal`

## Operator UI Authentication

Hubble UI and Longhorn UI can be protected with route-scoped Envoy Gateway OIDC `SecurityPolicy` resources. The policies are enabled by `scripts/dev/prepare-operator-oidc.sh` after the matching client secrets are written.

Create these ZITADEL OIDC applications manually:

| UI | Client ID | Redirect URI |
| --- | --- | --- |
| Hubble UI | `hubble-ui` | `https://hubble.mam.jku.internal/oauth2/callback` |
| Longhorn UI | `longhorn-ui` | `https://longhorn.mam.jku.internal/oauth2/callback` |

Use a confidential/web application type that issues a client secret. After creating both applications, run:

```sh
sh scripts/dev/prepare-operator-oidc.sh
./scripts/dev/deploy-platform.sh
```

The preparation script prompts for the two client secrets, writes SOPS-encrypted Kubernetes Secrets, and enables the route-scoped `SecurityPolicy` manifests.

Set the intended public Gateway IP with `spec.addresses` in `config/public-gateway.yaml`. The chosen IP must be inside the Cilium `CiliumLoadBalancerIPPool` configured in `infra/platform/cilium/l2-lab.yaml`.

Before exposing the MAM beyond the lab:

- point local/manual DNS records at the Envoy Gateway load balancer IP
- install the generated local root CA into trusted client stores
- add `HTTPRoute` resources for each public API
- apply OIDC/JWT `SecurityPolicy` resources after ZITADEL clients and secrets exist

Keep bulk media uploads out of the gateway path when possible. Use an authenticated API call to create an upload intent, return a pre-signed object-storage URL, and let the browser upload directly to object storage.
