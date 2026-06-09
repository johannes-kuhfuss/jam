# ZITADEL

ZITADEL is the planned OIDC/OAuth2 provider for jam human users and external machine clients.

The `HelmRelease` is intentionally suspended until the deployment has real values:

- generate a permanent 32-character `zitadel-masterkey` Secret
- replace the first instance admin email and password
- decide whether the bundled PostgreSQL chart is acceptable for the lab or whether an external PostgreSQL service should be used
- copy `templates/http-route.yaml` into this directory once the first encrypted ZITADEL secrets are committed

The configured lab identity hostname is `auth.mam.jku.internal`.

The master key cannot be changed after first initialization without losing access to encrypted ZITADEL data.
