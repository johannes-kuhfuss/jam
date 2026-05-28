# Infrastructure

This directory contains the infrastructure and operations configuration for the self-hosted jam deployment.

## Layout

- `terraform/`: infrastructure provisioning and reusable modules.
- `ansible/`: node bootstrap, K3s installation, and host hardening.
- `k3s/`: K3s-specific configuration, bootstrap manifests, and helper scripts.
- `kubernetes/`: Kubernetes manifests organized as shared bases and environment overlays.
- `helm/`: Helm charts and per-environment values.
- `gitops/`: Flux or Argo CD cluster reconciliation configuration.
- `secrets/`: encrypted secret definitions only.
- `policies/`: network, admission, and pod security policies.

