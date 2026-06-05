# Longhorn

Longhorn provides the default `StorageClass` for the lab cluster. Flux installs it from the official Longhorn Helm chart after the Talos host prerequisites are already present.

Host prerequisites are managed outside Flux:

- each Talos VM gets a dedicated Proxmox data disk
- Talos mounts that disk as a `UserVolumeConfig` named `longhorn`
- kubelet receives `/var/mnt/longhorn` as an extra bind mount
- the Talos installer image must include `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools`

The lab values default to a single-node setup:

- Longhorn data path: `/var/mnt/longhorn`
- default `StorageClass`: `longhorn`
- replica count: `1`
- UI exposure: internal service only

For a three-node lab, set both `defaultSettings.defaultReplicaCount` and `persistence.defaultClassReplicaCount` in `helm-release.yaml` to `3`.
