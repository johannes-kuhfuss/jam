# ZITADEL

ZITADEL is the planned OIDC/OAuth2 provider for jam human users and external machine clients.

The `HelmRelease` is intentionally suspended until the deployment has real values:

- generate a permanent 32-character `zitadel-masterkey` Secret
- replace the first instance admin email and password
- decide whether the bundled PostgreSQL chart is acceptable for the lab or whether an external PostgreSQL service should be used
- copy `templates/http-route.yaml` into this directory once the first encrypted ZITADEL secrets are committed

The configured lab identity hostname is `auth.mam.jku.internal`.

The master key cannot be changed after first initialization without losing access to encrypted ZITADEL data.

## Preparing the Lab Deployment

Use the helper script to fill the scaffolded files:

```sh
sh scripts/dev/prepare-zitadel.sh
```

The script prompts for:

- the external ZITADEL hostname
- the first instance admin username, email, and password
- whether to use the lab PostgreSQL HelmRelease
- the 32-character master key, or permission to generate one

The automated path currently supports the lab PostgreSQL HelmRelease in this directory. If you want to use an external PostgreSQL service, configure the chart values manually before unsuspending the release.

It then:

- writes `infra/gitops/secrets/lab/platform/zitadel-masterkey.secret.yaml`
- adds that Secret manifest to `infra/gitops/secrets/lab/kustomization.yaml`
- copies `templates/http-route.yaml` to `http-route.yaml`
- adds the route to this kustomization
- replaces the placeholder first-instance values in `helm-release.yaml`
- sets `spec.suspend` to `false`

After running the script, encrypt the generated Secret before committing:

```sh
sops --encrypt --in-place infra/gitops/secrets/lab/platform/zitadel-masterkey.secret.yaml
```

Only commit the encrypted Secret. The plaintext master key must not be committed.

## Manual Deployment Steps

If you do not use the helper script, make the same changes manually:

1. Copy `infra/gitops/secrets/lab/templates/zitadel-masterkey.secret.yaml` to `infra/gitops/secrets/lab/platform/zitadel-masterkey.secret.yaml`.
2. Replace the `masterkey` value with a permanent 32-character random alphanumeric value.
3. Encrypt the Secret with SOPS and add it to `infra/gitops/secrets/lab/kustomization.yaml`.
4. Replace the placeholder first-instance admin email and password in `helm-release.yaml`.
5. Decide whether the lab PostgreSQL HelmRelease is acceptable. If it is not, configure an external PostgreSQL service before unsuspending the release.
6. Copy `templates/http-route.yaml` to `http-route.yaml`, update the hostname if needed, and add it to this kustomization.
7. Change `spec.suspend` in `helm-release.yaml` to `false`.
8. Commit and push the GitOps changes so Flux can reconcile `jam-zitadel`.

Verify the deployment with:

```sh
kubectl -n flux-system get kustomization jam-zitadel
kubectl -n zitadel get helmrelease zitadel
kubectl -n zitadel get pods
kubectl -n zitadel get httproute zitadel
```

Make sure DNS for the configured hostname points to the Envoy Gateway address.
