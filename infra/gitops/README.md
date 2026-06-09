# GitOps

Flux reconciles steady-state lab cluster configuration from this directory.

`scripts/dev/bootstrap-gitops.sh` installs Flux into `flux-system` and creates:

- a `GitRepository` source named `jam` pointing at `https://github.com/johannes-kuhfuss/jam.git`
- a `Kustomization` named `jam-lab` pointing at `infra/gitops/clusters/lab`

The bootstrap uses public HTTPS read-only access. It does not push generated Flux manifests back to the repository and does not require deploy keys or tokens.

Add lab platform and application resources below `clusters/lab` or reference shared bases from that entry point.

## Secrets

Lab secrets are managed with SOPS and age under `infra/gitops/secrets/lab`.

Run this once per cluster before reconciling encrypted secrets:

```sh
scripts/dev/bootstrap-sops-age.sh
```

The script creates or reuses `infra/talos/generated/sops-age.agekey`, installs it as `flux-system/sops-age`, and writes the matching public recipient into `.sops.yaml`.

Use this pattern for new secrets:

```sh
mkdir -p infra/gitops/secrets/lab/platform
cp infra/gitops/secrets/lab/templates/zitadel-masterkey.secret.yaml infra/gitops/secrets/lab/platform/zitadel-masterkey.secret.yaml
sops --encrypt --in-place infra/gitops/secrets/lab/platform/zitadel-masterkey.secret.yaml
```

Then add the encrypted file to `infra/gitops/secrets/lab/kustomization.yaml`.
