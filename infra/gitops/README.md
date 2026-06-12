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

For the lab ZITADEL deployment, prepare and encrypt the generated Secret before bootstrapping Flux:

```sh
scripts/dev/prepare-zitadel.sh
sops --encrypt --in-place infra/gitops/secrets/lab/platform/zitadel-masterkey.secret.yaml
git add .sops.yaml infra/gitops
git commit -m "Prepare lab GitOps secrets and Zitadel"
git push
```

Flux reconciles the remote Git repository configured by `scripts/dev/bootstrap-gitops.sh`, so local GitOps changes must be committed and pushed before Flux can apply them.

For other secrets, copy a template or write a Kubernetes Secret manifest under `infra/gitops/secrets/lab`, encrypt it with SOPS, and add only the encrypted manifest to the relevant `kustomization.yaml`.
