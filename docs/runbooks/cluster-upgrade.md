# Cluster Upgrade

Operational notes for upgrading Talos, Kubernetes, Cilium, and cluster add-ons.

Current policy:

- Pin Talos template/image versions deliberately.
- Pin `talos_version` in `infra/opentofu/environments/lab/lab.auto.tfvars` to the Talos template version family.
- Pin `kubernetes_version` in `infra/opentofu/environments/lab/lab.auto.tfvars`.
- Pin the Cilium chart version through `CILIUM_VERSION` when running `scripts/dev/bootstrap-cilium.sh`; otherwise the script installs the chart repository default.
- Pin the Flux version by installing the desired `flux` CLI version on the ops runner before running `scripts/dev/bootstrap-gitops.sh`; otherwise the script installs the controller version bundled with the local CLI.
- Move Cilium and other platform upgrades into GitOps after the initial bootstrap workflow is adopted.
