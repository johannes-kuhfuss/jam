# Kubernetes

This directory contains Kubernetes manifests that are applied by the local deployment scripts.

Platform charts are installed with `scripts/dev/deploy-platform.sh` using Helm values from `infra/helm/values/platform`. Plain Kubernetes resources stay here and are applied with `kubectl apply -k`.

## Secrets

Lab secrets are managed with SOPS and age under `infra/kubernetes/secrets/lab`.

Run this once per cluster before encrypting lab secrets:

```sh
scripts/dev/bootstrap-sops-age.sh
```

The script creates or reuses `infra/talos/generated/sops-age.agekey` and writes the matching public recipient into `.sops.yaml`. The private key stays on the ops runner and is used by `scripts/dev/deploy-platform.sh` through local SOPS decryption.

For the lab ZITADEL deployment:

```sh
scripts/dev/prepare-zitadel.sh
sops --encrypt --in-place infra/kubernetes/secrets/lab/platform/zitadel-masterkey.secret.yaml
scripts/dev/deploy-platform.sh
```

For other secrets, copy a template or write a Kubernetes Secret manifest under `infra/kubernetes/secrets/lab`, encrypt it with SOPS, and add only the encrypted manifest to the relevant `kustomization.yaml`.
