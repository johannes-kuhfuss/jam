# Ops Runner

Use a small Linux machine as the operational runner for OpenTofu, Talos, Cilium bootstrap, Flux bootstrap, and Kubernetes administration.

## Required Tools

- `tofu`
- `talosctl`
- `kubectl`
- `helm`
- `flux`

Recommended tools for later cluster add-ons:

- `yq`

## Network Access

The runner needs access to:

- the Proxmox API, usually `https://<proxmox-host>:8006`
- the Talos node maintenance API on TCP port `50000`
- the Kubernetes API on TCP port `6443`
- the internet for provider, Talos, Helm chart, and container image downloads

## Lab Provisioning

Clone the repository onto the runner, then create the local OpenTofu variable file:

```sh
cp infra/opentofu/environments/lab/lab.auto.tfvars.example infra/opentofu/environments/lab/lab.auto.tfvars
```

Edit `lab.auto.tfvars` with the local Proxmox endpoint, API token, Talos template VM ID, datastore, IP addresses, and optional static MAC addresses.

Important values:

```hcl
proxmox_endpoint  = "https://pve.example.lan:8006/api2/json"
proxmox_api_token = "opentofu@pve!jam=<token-value>"
proxmox_insecure  = true

proxmox_node_name = "pve"
template_vm_id    = 9000
datastore_id      = "local-lvm"

network_bridge = "vmbr0"
vlan_id        = null
```

For one Talos node:

```hcl
talos_node_count = 1
talos_node_ipv4_addresses = [
  "192.168.1.50",
]
talos_node_mac_addresses = [
  "02:00:00:00:50:01",
]
api_virtual_ip = "192.168.1.60"
```

For three Talos nodes:

```hcl
talos_node_count = 3
talos_node_ipv4_addresses = [
  "192.168.1.50",
  "192.168.1.51",
  "192.168.1.52",
]
talos_node_mac_addresses = [
  "02:00:00:00:50:01",
  "02:00:00:00:50:02",
  "02:00:00:00:50:03",
]
api_virtual_ip = "192.168.1.60"
```

Reserve the MAC/IP pairs in DHCP so OpenTofu can reach Talos before the final static machine config is applied.

Adjust the gateway and DNS values for the local network:

```hcl
ipv4_prefix_length = 24
ipv4_gateway       = "192.168.1.1"
dns_domain         = "home.arpa"
dns_servers        = ["192.168.1.1"]
```

Run the combined lab provisioning script:

```sh
chmod +x scripts/dev/provision-lab.sh scripts/dev/deprovision-lab.sh scripts/dev/bootstrap-cilium.sh scripts/dev/bootstrap-gitops.sh
./scripts/dev/provision-lab.sh
./scripts/dev/bootstrap-cilium.sh
./scripts/dev/bootstrap-gitops.sh
```

The script runs OpenTofu and stores generated client configs under:

```text
infra/talos/generated/
```

It also installs the generated kubeconfig to the default kubeconfig path:

```text
~/.kube/config
```

The installed kubeconfig initially uses the first Talos node IP as the Kubernetes API server. This keeps `kubectl`, Helm, and the Cilium bootstrap working before kube-vip starts advertising `api_virtual_ip`. After Cilium and kube-vip are healthy, `scripts/dev/bootstrap-cilium.sh` switches the generated and default kubeconfig back to the API VIP.

`scripts/dev/bootstrap-gitops.sh` installs Flux after Cilium is healthy and configures it to reconcile the public repository at `https://github.com/johannes-kuhfuss/jam.git` on branch `main`, path `infra/gitops/clusters/lab`. Because the repository is public, the bootstrap uses read-only HTTPS and does not require deploy keys or tokens.

If an existing default kubeconfig is present, the script backs it up as `~/.kube/config.jam-backup.<timestamp>` and records that backup in `~/.kube/config.jam-managed`.

The script also installs the generated talosconfig to the default `talosctl` config path:

```text
$XDG_CONFIG_HOME/talos/config.yaml
```

If `XDG_CONFIG_HOME` is not set, it uses:

```text
~/.talos/config
```

If an existing default talosconfig is present, the script backs it up as `config.jam-backup.<timestamp>` in the same directory and records that backup in `config.jam-managed`.

Use the cluster with plain `kubectl`:

```sh
kubectl get nodes
```

Use Talos with plain `talosctl`:

```sh
talosctl dashboard
```

## Lab Deprovisioning

Destroy the OpenTofu-managed lab VMs from the runner:

```sh
./scripts/dev/deprovision-lab.sh
```

The script runs `tofu destroy`, removes generated Talos/Kubernetes client configs, and restores the previous default kubeconfig and talosconfig when the `config.jam-managed` markers are present. It does not delete the Proxmox VM template.

See `docs/runbooks/proxmox-talos-template.md` for the Proxmox VM template setup.
