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

Important values:

```hcl
proxmox_endpoint  = "https://pve.example.lan:8006/api2/json"
proxmox_api_token = "terraform@pve!jam=<token-value>"
proxmox_insecure  = true

proxmox_node_name       = "pve"
template_vm_id          = 9000
datastore_id            = "local-lvm"
cloud_init_datastore_id = "local-lvm"

network_bridge = "vmbr0"
vlan_id        = null

cloud_init_username = "jam"
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
```

For one K3s server:

```hcl
k3s_node_count = 1
k3s_node_ipv4_addresses = [
  "192.168.1.50",
]
```

For three K3s servers:

```hcl
k3s_node_count = 3
k3s_node_ipv4_addresses = [
  "192.168.1.50",
  "192.168.1.51",
  "192.168.1.52",
]
```

Adjust the gateway and DNS values for the local network:

```hcl
ipv4_prefix_length = 24
ipv4_gateway       = "192.168.1.1"
dns_domain         = "home.arpa"
dns_servers        = ["192.168.1.1"]
```

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

See `docs/runbooks/proxmox-cloud-init-template.md` for the Proxmox VM template setup.
