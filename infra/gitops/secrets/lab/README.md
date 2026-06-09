# Lab Secrets

Encrypted Kubernetes Secrets for the lab environment live here.

Use SOPS with age. Flux decrypts this path with the `sops-age` Secret in the `flux-system` namespace.

Recommended layout:

- platform secrets stay directly in this directory or under `platform/`
- application secrets go under `apps/<namespace-or-service>/`
- commit only SOPS-encrypted Secret manifests, not plaintext Secret values

Bootstrap the age key with:

```sh
scripts/dev/bootstrap-sops-age.sh
```

After bootstrap, copy one of the examples from `templates/`, replace the values, then encrypt it:

```sh
sops --encrypt --in-place infra/gitops/secrets/lab/platform/zitadel-masterkey.secret.yaml
```

Add encrypted files to `kustomization.yaml` after encryption. Do not add files from `templates/` directly.
