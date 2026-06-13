# Ops Runner

Use a small Linux machine as the operational runner for OpenTofu, Talos, Cilium bootstrap, platform deployment, and Kubernetes administration.

## Required Tools

- `tofu`
- `talosctl`
- `kubectl`
- `helm`
- `age` tooling, including `age-keygen`
- `sops`

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

Longhorn requires Talos system extensions for iSCSI and filesystem utilities. Prefer building the Talos template with `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools`. If the template does not include them, use a Talos Image Factory installer and set it explicitly:

```hcl
talos_installer_image = "factory.talos.dev/installer/<schematic-id>:v1.12.0"
```

The lab uses a smaller Talos root disk and a dedicated Longhorn data disk by default:

```hcl
talos_node_disk_size_gb    = 40
longhorn_data_disk_size_gb = 40
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

Before bootstrapping Cilium and deploying platform components, adjust the lab load balancer addressing:

- set the Cilium `LoadBalancer` IP pool in `infra/platform/cilium/l2-lab.yaml`
- set the Envoy Gateway `spec.addresses` IP in `infra/kubernetes/platform/gateway/envoy-gateway/config/public-gateway.yaml`
- point wildcard DNS for `*.mam.jku.internal` at that Envoy Gateway IP

The Envoy Gateway IP must be a free address inside the Cilium pool. See `docs/architecture/networking.md` for an example.

Run the lab provisioning sequence:

```sh
./scripts/dev/provision-lab.sh
./scripts/dev/bootstrap-cilium.sh
./scripts/dev/bootstrap-sops-age.sh
git status
./scripts/dev/deploy-platform.sh --prepare-zitadel
```

The deploy script applies the runner's local working tree directly. Review `git status` before deployment so local changes are intentional.

After ZITADEL is reachable at `https://auth.mam.jku.internal`, create OIDC applications for the operator UIs:

| UI | Type | Authentication Method | Suggested app name | Redirect URI |
| --- | --- | --- | --- | --- |
| Hubble UI | `Web` | `Code` | `hubble-ui` | `https://hubble.mam.jku.internal/oauth2/callback` |
| Longhorn UI | `Web` | `Code` | `longhorn-ui` | `https://longhorn.mam.jku.internal/oauth2/callback` |

Use the generated client IDs and client secrets from those applications. Then store them and enable the route-scoped Envoy Gateway policies:

```sh
sh scripts/dev/prepare-operator-oidc.sh
./scripts/dev/deploy-platform.sh
```

The preparation script writes SOPS-encrypted Secrets under `infra/kubernetes/secrets/lab/platform/operator-ui/`, writes the generated client IDs into the Hubble and Longhorn `SecurityPolicy` manifests, and adds those policies to their platform kustomizations.

The script runs OpenTofu and stores generated client configs under:

```text
infra/talos/generated/
```

It also installs the generated kubeconfig to the default kubeconfig path:

```text
~/.kube/config
```

The installed kubeconfig initially uses the first Talos node IP as the Kubernetes API server. This keeps `kubectl`, Helm, and the Cilium bootstrap working before kube-vip starts advertising `api_virtual_ip`. After Cilium and kube-vip are healthy, `scripts/dev/bootstrap-cilium.sh` switches the generated and default kubeconfig back to the API VIP.

`scripts/dev/provision-lab.sh` waits for the Kubernetes API to answer before exiting. The default timeout is 300 seconds and can be overridden with `KUBERNETES_API_TIMEOUT`.

`scripts/dev/bootstrap-sops-age.sh` generates a local age key under `infra/talos/generated/sops-age.agekey` when one does not already exist and updates `.sops.yaml` with the public age recipient. `scripts/dev/deploy-platform.sh` uses that key file by default unless `SOPS_AGE_KEY_FILE` or another SOPS age key environment variable is already set. The private key is ignored by Git through the existing `infra/talos/generated/` ignore rule. Keep an offline backup of this key; encrypted lab secrets cannot be decrypted without it.

`scripts/dev/deploy-platform.sh --prepare-zitadel` runs the ZITADEL preparation prompts before deployment. The preparation step writes the ZITADEL master key Secret manifest, adds it to the lab secrets kustomization, copies the ZITADEL HTTPRoute into place, updates the first-instance admin login values in `infra/helm/values/platform/zitadel.yaml`, and encrypts a generated plaintext Secret with SOPS before applying it. Set `ENCRYPT_ZITADEL_SECRET=false` only for a local throwaway deployment where you deliberately do not want SOPS encryption. The lab deploys PostgreSQL as a separate Helm release before ZITADEL, so the database service exists before the ZITADEL initialization hook runs.

`scripts/dev/deploy-platform.sh` installs Helm-managed platform components, decrypts lab secrets locally with SOPS when needed, and applies plain Kubernetes manifests from `infra/kubernetes`. If the ZITADEL master key Secret is missing and the script is running interactively, the default `PREPARE_ZITADEL=auto` behavior runs the preparation prompts. Readiness for the platform components is checked by `scripts/dev/blackbox-lab.sh`.

`scripts/dev/prepare-operator-oidc.sh` is intentionally separate from the main deployment because the ZITADEL applications and client secrets do not exist until after the first ZITADEL deployment is complete.

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
