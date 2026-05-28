# Infrastructure

This document captures the target on-prem hosting architecture for jam.

Initial direction:

- Self-hosted on-prem environment.
- K3s as the Kubernetes distribution.
- Infrastructure and cluster configuration stored in `infra/`.

Provisioning model:

- Proxmox hosts the K3s VM nodes.
- Terraform clones VM nodes from a Proxmox cloud-init template.
- Cloud-init injects the initial SSH user and key.
- Ansible bootstraps the operating system and installs K3s.
- The lab setup supports either one K3s server or three K3s servers.
