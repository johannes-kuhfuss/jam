# Cluster Upgrade

Operational notes for upgrading Talos, Kubernetes, Cilium, and cluster add-ons.

Current policy:

- Pin Talos template/image versions deliberately.
- Pin `talos_version` in `infra/opentofu/environments/lab/lab.auto.tfvars` to the Talos template version family.
- Pin `kubernetes_version` in `infra/opentofu/environments/lab/lab.auto.tfvars`.
- Pin the Cilium chart version through `CILIUM_VERSION` when running `scripts/dev/bootstrap-cilium.sh`; otherwise the script installs the chart repository default.
- Pin platform chart versions in `scripts/dev/deploy-platform.sh`.
- Pin platform chart values under `infra/helm/values/platform`.
- Keep Talos installer images aligned with the required Longhorn host extensions: `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools`.
- Run `scripts/dev/deploy-platform.sh` after changing platform chart versions or values.
- Re-run `scripts/dev/prepare-operator-oidc.sh` only when replacing the Hubble or Longhorn ZITADEL OIDC client secrets.
