# Infrastructure

This directory contains the infrastructure and operations configuration for the self-hosted jam deployment.

## Layout

- `opentofu/`: Proxmox VM provisioning and Talos cluster bootstrap.
- `talos/`: Talos machine configuration patches and generated local client configs.
- `platform/`: first-wave platform bootstrap manifests, including Cilium and kube-vip notes.
- `kubernetes/`: Kubernetes manifests organized as shared bases and environment overlays.
- `helm/`: Helm charts and per-environment values.
- `gitops/`: Flux or Argo CD cluster reconciliation configuration.
- `secrets/`: encrypted secret definitions only.
- `policies/`: network, admission, and pod security policies.

## Talos Lab Flow

The lab environment supports either one converged Talos control-plane node or a three-node redundant control-plane cluster running as VMs on Proxmox. Separate worker pools are intentionally out of scope for now.

1. Create a Talos Image Factory based VM template in Proxmox.
2. Copy `opentofu/environments/lab/lab.auto.tfvars.example` to `lab.auto.tfvars` and fill in the local values.
3. Set `talos_node_count` to `1` or `3` and provide matching static IP addresses.
4. Configure DHCP reservations for the static MAC/IP pairs used for first Talos maintenance contact.
5. Run OpenTofu from `opentofu/environments/lab`.
6. Bootstrap Cilium with `scripts/dev/bootstrap-cilium.sh`.
7. Run the blackbox smoke test with `scripts/dev/blackbox-lab.sh`.
8. Hand Cilium ownership to GitOps after the cluster is healthy.

```sh
./scripts/dev/provision-lab.sh
./scripts/dev/bootstrap-cilium.sh
./scripts/dev/blackbox-lab.sh
```

Generated client configs are stored in:

```text
infra/talos/generated/
```

The provisioning script also installs the generated kubeconfig to `~/.kube/config` and the generated talosconfig to the default `talosctl` config path, backing up existing default configs first. The installed kubeconfig uses the first Talos node IP during bootstrap; after Cilium and kube-vip are healthy, the Cilium bootstrap script switches it back to the API VIP. After provisioning, `kubectl` and `talosctl` can use the lab cluster without extra config flags.

OpenTofu owns the Proxmox VMs and Talos bootstrap. The Cilium bootstrap script performs the first CNI install because the cluster starts without a CNI and with kube-proxy disabled. GitOps should own Cilium configuration and upgrades after that initial bootstrap.

Until Cilium is installed, Kubernetes nodes may report `NotReady`; that is expected for this bootstrap model.

The blackbox test verifies that `kubectl` can reach the cluster, `talosctl` can reach the Talos API, Cilium and its CRDs are present, and a temporary restricted-profile container workload can be scheduled and reached through an in-cluster Service. It uses `infra/talos/generated/kubeconfig` and `infra/talos/generated/talosconfig` by default; override them with `KUBECONFIG` and `TALOSCONFIG` if needed.

See `docs/runbooks/proxmox-talos-template.md` for Proxmox template setup and `docs/runbooks/ops-runner.md` for runner setup notes.
