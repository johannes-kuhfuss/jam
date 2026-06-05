# Backup And Restore

Operational notes for backing up and restoring jam infrastructure and data.

Longhorn is the default Kubernetes persistent storage provider. Volume replicas protect against disk or node loss inside the cluster, but they are not a backup.

Use an S3-compatible backup target for Longhorn volume backups. Prefer an object store outside the Kubernetes cluster, such as a provider-hosted bucket or MinIO on separate Proxmox/NAS storage. Avoid using in-cluster MinIO on Longhorn as the only backup target because it depends on the same cluster and storage layer being protected.

Initial lab Longhorn backup target configuration is intentionally unset. Add the backup target after object storage and secret management are in place.
