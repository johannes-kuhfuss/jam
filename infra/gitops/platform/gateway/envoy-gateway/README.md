# Envoy Gateway

Envoy Gateway is the public HTTP/gRPC edge for jam APIs.

The active configuration installs Envoy Gateway and creates a lab `Gateway` named `public-api`. The listener is HTTP-only until DNS and TLS certificate management are selected. Before exposing the MAM publicly:

- replace `*.jam.example` with the real API hostname pattern
- add an HTTPS listener with a real TLS certificate Secret
- add `HTTPRoute` resources for each public API
- apply OIDC/JWT `SecurityPolicy` resources after ZITADEL clients and secrets exist

Keep bulk media uploads out of the gateway path when possible. Use an authenticated API call to create an upload intent, return a pre-signed object-storage URL, and let the browser upload directly to object storage.
