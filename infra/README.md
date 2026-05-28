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

## K3s lab flow

The initial lab environment supports either one K3s server node or a three-server K3s cluster running as VMs on Proxmox.

1. Create a Debian or Ubuntu cloud-init VM template in Proxmox.
2. Copy `terraform/environments/lab/terraform.tfvars.example` to `terraform.tfvars` and fill in the local values.
3. Set `k3s_node_count` to `1` or `3` and provide the matching number of static IP addresses.
4. Run Terraform from `terraform/environments/lab`.
5. Copy `ansible/inventories/lab/hosts.yml.example` to `hosts.yml` and set the VM IPs from Terraform output.
6. Run the Ansible bootstrap and K3s install playbooks.

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

On Linux:

```sh
./scripts/dev/provision-lab.sh
```

To destroy the Terraform-managed lab VMs from Linux:

```sh
./scripts/dev/deprovision-lab.sh
```

After provisioning, the generated kubeconfig is stored in `infra/k3s/generated/`.

```sh
. ./infra/k3s/scripts/kubeconfig.sh
kubectl get nodes
```

Terraform owns the Proxmox VM. Ansible owns host configuration and K3s installation. Kubernetes add-ons are intentionally left for a later GitOps-driven step.

In three-node mode, the first inventory host initializes the K3s cluster and the remaining two servers join it. Keep the server count odd; the supported configuration options are intentionally limited to `1` and `3`.

See `docs/runbooks/proxmox-cloud-init-template.md` for Proxmox template setup and `docs/runbooks/ops-runner.md` for Linux runner setup notes.
