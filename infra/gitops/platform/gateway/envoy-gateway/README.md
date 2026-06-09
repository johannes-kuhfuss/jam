# Envoy Gateway

Envoy Gateway is the public HTTP/gRPC edge for jam APIs.

The active configuration installs Envoy Gateway and creates a lab `Gateway` named `public-api`.

- `http` listens on `*.mam.jku.internal`
- `https` listens on `*.mam.jku.internal`
- TLS terminates with the cert-manager managed `mam-jku-internal-wildcard-tls` Secret

Before exposing the MAM beyond the lab:

- point local/manual DNS records at the Envoy Gateway load balancer IP
- install the generated local root CA into trusted client stores
- add `HTTPRoute` resources for each public API
- apply OIDC/JWT `SecurityPolicy` resources after ZITADEL clients and secrets exist

Keep bulk media uploads out of the gateway path when possible. Use an authenticated API call to create an upload intent, return a pre-signed object-storage URL, and let the browser upload directly to object storage.
