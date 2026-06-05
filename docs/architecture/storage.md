# Storage

This document captures storage decisions for media assets, metadata, backups, and derived files.

## Kubernetes Persistent Storage

Longhorn is the default Kubernetes storage provider for the lab cluster. It is installed by Flux from `infra/gitops/platform/longhorn` after Cilium and Flux are healthy.

OpenTofu and Talos own the host prerequisites:

- each Talos VM has a dedicated Proxmox data disk for Longhorn
- Talos mounts that disk as a `UserVolumeConfig` named `longhorn`
- Longhorn stores replicas at `/var/mnt/longhorn`
- kubelet receives `/var/mnt/longhorn` as a bind mount

The Talos image must include the `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools` system extensions. Prefer baking them into the Proxmox Talos template through Talos Image Factory. If the template does not include them, use a matching Talos Image Factory installer image and set `talos_installer_image` in `lab.auto.tfvars`.

The lab defaults to single-node development:

- Talos root disk: 40 GiB
- Longhorn data disk: 40 GiB per node
- Longhorn replica count: 1
- Longhorn is the default `StorageClass`

For a three-node lab, set the Longhorn replica count to `3` in `infra/gitops/platform/longhorn/helm-release.yaml`.

Talos v1.12 requires a minimum 10 GiB system disk and recommends 100 GiB. The lab uses 40 GiB for the root disk because workload data is moved to a separate Longhorn disk.

## Shared Data

Use Longhorn `ReadWriteOnce` volumes for service-local persistent state. Use S3-compatible object storage for shared media, uploads, exports, derived assets, and backup targets. Longhorn `ReadWriteMany` volumes should be treated as an exception for workloads that truly require a shared POSIX filesystem.
