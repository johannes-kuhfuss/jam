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

For three-node clusters, configure a stable Kubernetes API endpoint before running the K3s install playbook. Use a VIP, load balancer, or DNS name that resolves to the API front end:

```yaml
# infra/ansible/inventories/lab/group_vars/k3s_servers.yml
k3s_api_endpoint: "k3s-api.home.arpa"
k3s_tls_sans:
  - "192.168.1.60"
```

The default endpoint is the first K3s server IP, which is acceptable for a single-node lab but leaves API access tied to that node.

K3s installs use the pinned `k3s_version` in `infra/ansible/inventories/lab/group_vars/k3s_servers.yml`. Update that value deliberately when following the cluster upgrade runbook.

Adjust the gateway and DNS values for the local network:

```hcl
ipv4_prefix_length = 24
ipv4_gateway       = "192.168.1.1"
dns_domain         = "home.arpa"
dns_servers        = ["192.168.1.1"]
```

Run the combined lab provisioning script:

```sh
chmod +x scripts/dev/provision-lab.sh scripts/dev/deprovision-lab.sh infra/k3s/scripts/install.sh infra/k3s/scripts/kubeconfig.sh
./scripts/dev/provision-lab.sh
```

The script runs Terraform, writes `infra/ansible/inventories/lab/hosts.yml`, then runs the Ansible bootstrap and K3s install playbooks.

To install the generated kubeconfig as the default kubeconfig:

```sh
./infra/k3s/scripts/kubeconfig.sh
kubectl get nodes
```

The script copies the generated kubeconfig to `~/.kube/config`, sets permissions to `0600`, and backs up an existing default kubeconfig before replacing it.

The generated kubeconfig is stored under:

```text
infra/k3s/generated/
```

For the default node name, the file is:

```text
infra/k3s/generated/jam-k3s-01.yaml
```

The kubeconfig is fetched from the first K3s server and rewritten to use `k3s_api_endpoint` instead of `127.0.0.1`.

`terraform.tfvars`, generated Ansible inventories, Terraform state, and generated kubeconfigs are local runner state and must not be committed.

## Lab deprovisioning

Destroy the Terraform-managed lab VMs from the Linux runner:

```sh
./scripts/dev/deprovision-lab.sh
```

The script runs `terraform destroy`, removes the generated Ansible inventory, and removes generated kubeconfig files. It does not delete the Proxmox VM template.

See `docs/runbooks/proxmox-cloud-init-template.md` for the Proxmox VM template setup.
