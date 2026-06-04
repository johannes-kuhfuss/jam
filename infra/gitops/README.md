# GitOps

Flux reconciles steady-state lab cluster configuration from this directory.

`scripts/dev/bootstrap-gitops.sh` installs Flux into `flux-system` and creates:

- a `GitRepository` source named `jam` pointing at `https://github.com/johannes-kuhfuss/jam.git`
- a `Kustomization` named `jam-lab` pointing at `infra/gitops/clusters/lab`

The bootstrap uses public HTTPS read-only access. It does not push generated Flux manifests back to the repository and does not require deploy keys or tokens.

Add lab platform and application resources below `clusters/lab` or reference shared bases from that entry point.
