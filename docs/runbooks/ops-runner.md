# Ops Runner

Use a small Linux machine as the operational runner for Terraform, Ansible, and Kubernetes administration.

## Required tools

- `terraform`
- `ansible`
- `python3`
- `ssh`
- `jq`
- `kubectl`

Recommended tools for later cluster add-ons:

- `helm`
- `flux`
- `yq`

## Network access

The runner needs access to:

- the Proxmox API, usually `https://<proxmox-host>:8006`
- the VM network over SSH
- the K3s API on TCP port `6443`
- the internet for downloading the K3s installer during Ansible runs

## Lab provisioning

Clone the repository onto the Linux runner, then create the local Terraform variable file:

```sh
cp infra/terraform/environments/lab/terraform.tfvars.example infra/terraform/environments/lab/terraform.tfvars
```

Edit `terraform.tfvars` with the local Proxmox endpoint, API token, template VM ID, datastore, SSH key, and IP addresses.

Run the combined lab provisioning script:

```sh
chmod +x scripts/dev/provision-lab.sh infra/k3s/scripts/install.sh infra/k3s/scripts/kubeconfig.sh
./scripts/dev/provision-lab.sh
```

The script runs Terraform, writes `infra/ansible/inventories/lab/hosts.yml`, then runs the Ansible bootstrap and K3s install playbooks.

To use the generated kubeconfig in a shell:

```sh
. ./infra/k3s/scripts/kubeconfig.sh
kubectl get nodes
```

`terraform.tfvars`, generated Ansible inventories, Terraform state, and generated kubeconfigs are local runner state and must not be committed.
