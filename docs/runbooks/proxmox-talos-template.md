# Proxmox Talos Template

Create this template once on the Proxmox host. OpenTofu clones this VM when provisioning the Talos lab nodes.

## Template Values

Adjust these values before running the commands:

```sh
export TEMPLATE_ID=9000
export TEMPLATE_NAME=talos-nocloud
export STORAGE=local-lvm
export BRIDGE=vmbr0
export TALOS_VERSION=v1.13.3
export SCHEMATIC_ID=replace-with-image-factory-schematic-id
```

`TEMPLATE_ID` must match `template_vm_id` in `infra/opentofu/environments/lab/lab.auto.tfvars`.

## Create The Template

Use Talos Image Factory to create a `nocloud` raw disk image for the pinned Talos version and schematic. Prefer a custom schematic when you need system extensions such as the QEMU guest agent.
1. Navigate to the Talos Image Factory
2. As "Hardware Type" choose "Cloud Server"
3. Choose the recommended Talos version and update the version number in the EXPORT command (see above)
4. For "Cloud" choose "Nocloud"
5. For machine architecture choose "amd64" and leave "SecureBoot" disabled
6. From the "System Extensions" select the "siderolabs/qemu-guest-agent"
7. Do not change anything on the "Customization" page
8. Note down your schematic image ID and adjust the EXPORT command accordingly

```sh
cd /var/lib/vz/template/iso

wget "https://factory.talos.dev/image/${SCHEMATIC_ID}/${TALOS_VERSION}/nocloud-amd64.raw.xz" \
  -O "talos-${TALOS_VERSION}-${SCHEMATIC_ID}-nocloud-amd64.raw.xz"

xz -d "talos-${TALOS_VERSION}-${SCHEMATIC_ID}-nocloud-amd64.raw.xz"

qm create "$TEMPLATE_ID" \
  --name "$TEMPLATE_NAME" \
  --memory 8192 \
  --cores 4 \
  --net0 virtio,bridge="$BRIDGE" \
  --scsihw virtio-scsi-pci \
  --ostype l26 \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=0

qm importdisk "$TEMPLATE_ID" \
  "talos-${TALOS_VERSION}-${SCHEMATIC_ID}-nocloud-amd64.raw" \
  "$STORAGE"

qm set "$TEMPLATE_ID" \
  --scsi0 "$STORAGE:vm-$TEMPLATE_ID-disk-0" \
  --boot order=scsi0

qm template "$TEMPLATE_ID"
```

If the schematic includes `siderolabs/qemu-guest-agent`, enable the guest agent on the template:

```sh
qm set "$TEMPLATE_ID" --agent enabled=1
```

Then set this in `lab.auto.tfvars`:

```hcl
talos_qemu_agent_enabled = true
```

Both sides are required: the Talos image must include and run the guest agent extension, and Proxmox must expose the QEMU guest agent channel to the VM.

## First Contact Networking

OpenTofu must reach the Talos maintenance API before the final static network configuration is applied. Use static MAC addresses and DHCP reservations so each cloned VM initially receives the same IP listed in `talos_node_ipv4_addresses`.

The VM MAC addresses are configured in:

```hcl
talos_node_mac_addresses = [
  "02:00:00:00:50:01",
]
```

For a three-node lab, reserve all three MAC/IP pairs.

## OpenTofu Token Permissions

The Proxmox API token used by OpenTofu needs permission to clone the template and create VMs.

For a lab environment, the simplest setup is:

```sh
pveum user add opentofu@pve
pveum aclmod / -user opentofu@pve -role Administrator
pveum user token add opentofu@pve jam --privsep 0
```

Use the generated token value in `lab.auto.tfvars`:

```hcl
proxmox_api_token = "opentofu@pve!jam=<token-value>"
```
