# Infrastructure

This document captures the target on-prem hosting architecture for jam.

Initial direction:

- Self-hosted on-prem environment.
- Proxmox hosts Talos Linux VM nodes.
- Talos provides the immutable Kubernetes node OS and Kubernetes bootstrap.
- Cilium is the Kubernetes CNI and replaces kube-proxy.
- OpenTofu automates Proxmox VM creation and Talos cluster bootstrap.
- Flux reconciles steady-state cluster configuration after the network is healthy.

Provisioning model:

- Talos nodes are cloned from a reusable Proxmox VM template built from Talos Image Factory assets.
- The lab supports either one converged control-plane node or three converged control-plane nodes.
- OpenTofu applies Talos machine configs and bootstraps Kubernetes.
- kube-vip provides the Kubernetes API VIP.
- Cilium is installed once by a bootstrap script because the cluster starts without a CNI.
- Flux is installed once after Cilium is healthy, using read-only HTTPS access to the public repository.
- GitOps takes over steady-state platform and application ownership from `infra/gitops/clusters/lab`.
- Cilium L2 announcements provide lab `LoadBalancer` Service IP advertisement.

Known lab tradeoffs:

- Initial Talos maintenance access depends on DHCP reservations matching the configured VM MAC addresses.
- Talos secrets and generated client configs are stored in local OpenTofu state/output for the lab. A production-ready setup should move those secrets into a dedicated secret manager.
