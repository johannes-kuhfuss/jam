# ZITADEL

ZITADEL is the planned OIDC/OAuth2 provider for jam human users and external machine clients.

Before deploying it:

- generate a permanent 32-character `zitadel-masterkey` Secret
- replace the first instance admin login, email, and password in `infra/helm/values/platform/zitadel.yaml`
- decide whether the bundled PostgreSQL chart is acceptable for the lab or whether an external PostgreSQL service should be used
- keep `http-route.yaml` in this directory for the configured external hostname

The configured lab identity hostname is `auth.mam.jku.internal`.

The master key cannot be changed after first initialization without losing access to encrypted ZITADEL data.

## Preparing The Lab Deployment

Use the platform deploy script to run the preparation prompts and then deploy:

```sh
sh scripts/dev/deploy-platform.sh --prepare-zitadel
```

The script prompts for:

- the external ZITADEL hostname
- the first instance admin email, login name, and password
- whether to use the lab PostgreSQL chart
- the 32-character master key, or permission to generate one

The automated path currently supports the lab PostgreSQL chart. If you want to use an external PostgreSQL service, configure the chart values manually before deployment.

It then:

- writes `infra/kubernetes/secrets/lab/platform/zitadel-masterkey.secret.yaml`
- adds that Secret manifest to `infra/kubernetes/secrets/lab/kustomization.yaml`
- copies `templates/http-route.yaml` to `http-route.yaml`
- adds the route to this kustomization
- replaces the placeholder first-instance login values in `infra/helm/values/platform/zitadel.yaml`

If you run `scripts/dev/prepare-zitadel.sh` directly, encrypt the generated Secret before deployment:

```sh
sops --encrypt --in-place infra/kubernetes/secrets/lab/platform/zitadel-masterkey.secret.yaml
```

Only commit the encrypted Secret. The plaintext master key must not be committed.

## Manual Deployment Steps

If you do not use the helper script, make the same changes manually:

1. Copy `infra/kubernetes/secrets/lab/templates/zitadel-masterkey.secret.yaml` to `infra/kubernetes/secrets/lab/platform/zitadel-masterkey.secret.yaml`.
2. Replace the `masterkey` value with a permanent 32-character random alphanumeric value.
3. Encrypt the Secret with SOPS and add it to `infra/kubernetes/secrets/lab/kustomization.yaml`.
4. Replace the placeholder first-instance admin login, email, and password in `infra/helm/values/platform/zitadel.yaml`.
5. Decide whether the lab PostgreSQL chart is acceptable. If it is not, configure an external PostgreSQL service before deployment.
6. Copy `templates/http-route.yaml` to `http-route.yaml`, update the hostname if needed, and add it to this kustomization.
7. Run `scripts/dev/deploy-platform.sh`, or run `scripts/dev/deploy-platform.sh --prepare-zitadel` to let the deploy script perform the preparation step.

Verify the deployment with:

```sh
helm -n zitadel status zitadel
kubectl -n zitadel get pods
kubectl -n zitadel get httproute zitadel
```

Make sure DNS for the configured hostname points to the Envoy Gateway address.

## Operator UI OIDC Clients

After ZITADEL is running, create OIDC clients for the operator UIs if you want Envoy Gateway authentication in front of them:

| UI | Client ID | Redirect URI |
| --- | --- | --- |
| Hubble UI | `hubble-ui` | `https://hubble.mam.jku.internal/oauth2/callback` |
| Longhorn UI | `longhorn-ui` | `https://longhorn.mam.jku.internal/oauth2/callback` |

Then run:

```sh
sh scripts/dev/prepare-operator-oidc.sh
./scripts/dev/deploy-platform.sh
```
