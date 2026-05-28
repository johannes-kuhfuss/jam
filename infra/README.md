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

## Single-node K3s lab flow

The initial lab environment is designed for one K3s node running as a VM on Proxmox.

1. Create a Debian or Ubuntu cloud-init VM template in Proxmox.
2. Copy `terraform/environments/lab/terraform.tfvars.example` to `terraform.tfvars` and fill in the local values.
3. Run Terraform from `terraform/environments/lab`.
4. Copy `ansible/inventories/lab/hosts.yml.example` to `hosts.yml` and set the VM IP from Terraform output.
5. Run the Ansible bootstrap and K3s install playbooks.

```powershell
cd infra/terraform/environments/lab
terraform init
terraform apply

cd ../../../ansible
ansible-playbook -i inventories/lab/hosts.yml playbooks/bootstrap-nodes.yml
ansible-playbook -i inventories/lab/hosts.yml playbooks/install-k3s.yml
```

Or run the combined local orchestration script:

```powershell
.\scripts\dev\provision-lab.ps1
```

Terraform owns the Proxmox VM. Ansible owns host configuration and K3s installation. Kubernetes add-ons are intentionally left for a later GitOps-driven step.
