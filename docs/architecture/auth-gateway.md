# Authentication, Gateway, and Service Mesh

jam uses separate identity layers for users, external machine clients, and in-cluster workloads.

## Decisions

- ZITADEL is the preferred OIDC/OAuth2 identity provider.
- Envoy Gateway is the public HTTP/gRPC API gateway.
- Istio ambient mode provides service-to-service mTLS and workload identity.
- Fine-grained authorization is deferred, but the gateway and mesh must leave room for OPA or Envoy external authorization.
- Large browser uploads should use signed object-storage URLs instead of streaming media through the API gateway.

## Request Paths

Public API requests:

```text
browser or external API client -> Envoy Gateway -> mesh mTLS -> service
```

Operator UI requests:

```text
browser -> Envoy Gateway OIDC policy -> Hubble UI or Longhorn UI
```

Internal service calls:

```text
service A -> mesh mTLS -> service B
```

Large uploads:

```text
browser -> API upload intent -> signed object URL -> object storage -> ingest event
```

## Identity Boundaries

ZITADEL owns human login, browser OIDC flows, external machine clients, and client credentials.

Istio owns in-cluster workload identity and mTLS. Internal services should trust mesh identity for service-to-service authentication and use forwarded user context only when a request is acting on behalf of a user.

## Operator UI Authentication

Lab operator UIs are exposed through Envoy Gateway and should use route-scoped OIDC policies instead of their own public unauthenticated endpoints.

Current operator UI clients:

| UI | Hostname | Suggested app name | Redirect URI |
| --- | --- | --- | --- |
| Hubble UI | `hubble.mam.jku.internal` | `hubble-ui` | `https://hubble.mam.jku.internal/oauth2/callback` |
| Longhorn UI | `longhorn.mam.jku.internal` | `longhorn-ui` | `https://longhorn.mam.jku.internal/oauth2/callback` |

The OIDC clients are created manually in ZITADEL for now. Use application type `Web` and authentication method `Code` for both clients. ZITADEL generates the actual OIDC client IDs; `scripts/dev/prepare-operator-oidc.sh` records those IDs in the route-scoped Envoy Gateway `SecurityPolicy` manifests and stores the client secrets as SOPS-encrypted Kubernetes Secrets.

## Protocol Constraints

HTTP and gRPC are first-class API protocols. WebSockets are acceptable when needed, but require explicit timeout and authentication-lifetime design.

Raw TCP, RTMP, SMB, NFS, and similar protocols should be treated as exceptions. They cannot use the same gateway OIDC/JWT policy model and usually require mesh policy, network policy, protocol-specific authentication, or a dedicated ingress path.
