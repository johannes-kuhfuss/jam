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

Use Talos Image Factory to create a `nocloud` raw disk image for the pinned Talos version and schematic. The schematic should include Longhorn's required storage extensions and a serial console kernel argument for the Proxmox console. Include the QEMU guest agent extension too if `talos_qemu_agent_enabled` will be set to `true`.

1. Navigate to the Talos Image Factory
2. As "Hardware Type" choose "Cloud Server"
3. Choose the recommended Talos version and update the version number in the EXPORT command (see above)
4. For "Cloud" choose "Nocloud"
5. For machine architecture choose "amd64" and enable "SecureBoot"
6. From "System Extensions", select:
   - `siderolabs/iscsi-tools`
   - `siderolabs/util-linux-tools`
   - `siderolabs/qemu-guest-agent` if Proxmox guest agent support is desired
7. On the "Customization" page, add this extra kernel command line argument: `console=ttyS0,115200`
8. Note down your schematic image ID and adjust the EXPORT command accordingly

The equivalent schematic YAML is:

```yaml
customization:
  extraKernelArgs:
    - console=ttyS0,115200
  systemExtensions:
    officialExtensions:
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
      - siderolabs/qemu-guest-agent
```

`siderolabs/iscsi-tools` and `siderolabs/util-linux-tools` are required for Longhorn on Talos. Without them, Longhorn can reconcile from Flux but volume attachment and filesystem operations will fail on the nodes.

```sh
cd /var/lib/vz/template/iso

wget "https://factory.talos.dev/image/${SCHEMATIC_ID}/${TALOS_VERSION}/nocloud-amd64.raw.xz" \
  -O "talos-${TALOS_VERSION}-${SCHEMATIC_ID}-nocloud-amd64.raw.xz"

xz -d "talos-${TALOS_VERSION}-${SCHEMATIC_ID}-nocloud-amd64.raw.xz"

qm create "$TEMPLATE_ID" \
  --name "$TEMPLATE_NAME" \
  --memory 8192 \
  --balloon 0 \
  --cores 4 \
  --net0 virtio,bridge="$BRIDGE" \
  --bios ovmf \
  --machine q35 \
  --scsihw virtio-scsi-pci \
  --ostype l26 \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=0

qm set "$TEMPLATE_ID" \
  --efidisk0 "$STORAGE:0,efitype=4m,pre-enrolled-keys=1"

qm importdisk "$TEMPLATE_ID" \
  "talos-${TALOS_VERSION}-${SCHEMATIC_ID}-nocloud-amd64.raw" \
  "$STORAGE"

qm set "$TEMPLATE_ID" \
  --scsi0 "$STORAGE:vm-$TEMPLATE_ID-disk-1,cache=none,discard=on" \
  --boot order=scsi0

qm template "$TEMPLATE_ID"
```

The template follows the Talos Proxmox baseline: OVMF UEFI firmware, q35 machine type, SecureBoot with pre-enrolled EFI keys, VirtIO SCSI controller, raw disk, no memory ballooning, virtio networking, 4 MiB EFI disk, and a socket serial console. The root disk uses `cache=none`, which is the Talos-documented alternative to write-through for clustered environments, and `discard=on` for TRIM support on compatible storage.

SecureBoot requires the Image Factory download to be generated with SecureBoot enabled. If the Proxmox EFI disk uses pre-enrolled keys but the Talos image is not SecureBoot-capable, the VM will not boot.

The Proxmox `--serial0 socket` and `--vga serial0` settings expose the serial device to the VM console. The Image Factory `extraKernelArgs` setting makes Talos write kernel and console output to that serial device.

If the schematic includes `siderolabs/qemu-guest-agent`, enable the guest agent on the template:

```sh
qm set "$TEMPLATE_ID" --agent enabled=1
```

Then set this in `lab.auto.tfvars`:

```hcl
talos_qemu_agent_enabled = true
```

Both sides are required: the Talos image must include and run the guest agent extension, and Proxmox must expose the QEMU guest agent channel to the VM.

If the Talos template already includes the Longhorn extensions, `talos_installer_image` can remain unset in `lab.auto.tfvars`. Set `talos_installer_image` only when the VM template does not already contain those extensions and the install should use a specific Image Factory installer.

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

## First Contact Networking

OpenTofu must reach the Talos maintenance API before the final static network configuration is applied. Use static MAC addresses and DHCP reservations so each cloned VM initially receives the same IP listed in `talos_node_ipv4_addresses` in `infra/opentofu/environments/lab/lab.auto.tfvars`.

The VM MAC addresses are configured in `infra/opentofu/environments/lab/lab.auto.tfvars`:

```hcl
talos_node_mac_addresses = [
  "02:00:00:00:50:01",
]
```

For a three-node lab, reserve all three MAC/IP pairs.
