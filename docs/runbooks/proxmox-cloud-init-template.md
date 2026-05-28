# Proxmox Cloud-Init Template

Create this template once on the Proxmox host. Terraform clones this VM when provisioning the K3s lab nodes.

## Template values

Adjust these values before running the commands:

```sh
export TEMPLATE_ID=9000
export TEMPLATE_NAME=debian-12-cloudinit
export STORAGE=local-lvm
export BRIDGE=vmbr0
```

`TEMPLATE_ID` must match `template_vm_id` in `infra/terraform/environments/lab/terraform.tfvars`.

## Create the template

Run these commands on the Proxmox host shell:

```sh
cd /var/lib/vz/template/iso

wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

apt update
apt install -y libguestfs-tools

virt-customize -a debian-12-generic-amd64.qcow2 \
  --install qemu-guest-agent,cloud-init,curl,ca-certificates \
  --run-command 'systemctl enable qemu-guest-agent'

qm create "$TEMPLATE_ID" \
  --name "$TEMPLATE_NAME" \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge="$BRIDGE" \
  --scsihw virtio-scsi-pci \
  --ostype l26 \
  --agent enabled=1

qm importdisk "$TEMPLATE_ID" debian-12-generic-amd64.qcow2 "$STORAGE"

qm set "$TEMPLATE_ID" \
  --scsi0 "$STORAGE:vm-$TEMPLATE_ID-disk-0" \
  --boot c \
  --bootdisk scsi0

qm set "$TEMPLATE_ID" --ide2 "$STORAGE:cloudinit"

qm set "$TEMPLATE_ID" \
  --serial0 socket \
  --vga serial0

qm set "$TEMPLATE_ID" --ciuser jam
qm set "$TEMPLATE_ID" --ipconfig0 ip=dhcp

qm template "$TEMPLATE_ID"
```

After creation, the template should show:

- disk on `scsi0`
- cloud-init drive on `ide2`
- QEMU guest agent enabled
- serial console configured

## Terraform token permissions

The Proxmox API token used by Terraform needs permission to clone the template and create VMs.

For a lab environment, the simplest setup is:

```sh
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Administrator
pveum user token add terraform@pve jam --privsep 0
```

Use the generated token value in `terraform.tfvars`:

```hcl
proxmox_api_token = "terraform@pve!jam=<token-value>"
```

If token privilege separation is enabled, the token needs its own ACLs. The user's ACLs are not enough.

## SSH access

The cloud-init user is configured by Terraform:

```hcl
cloud_init_username = "jam"
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
```

There is no generated password for `jam`. Access is key-based:

```sh
ssh jam@192.168.1.50
```

