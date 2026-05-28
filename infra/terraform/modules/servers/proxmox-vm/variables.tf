variable "name" {
  type        = string
  description = "VM name."
}

variable "description" {
  type        = string
  description = "VM description."
  default     = "Managed by Terraform."
}

variable "proxmox_node_name" {
  type        = string
  description = "Proxmox node that will host the VM."
}

variable "vm_id" {
  type        = number
  description = "Proxmox VM ID."
}

variable "template_vm_id" {
  type        = number
  description = "Cloud-init template VM ID to clone."
}

variable "tags" {
  type        = list(string)
  description = "Proxmox tags assigned to the VM."
  default     = []
}

variable "on_boot" {
  type        = bool
  description = "Start the VM when the Proxmox node boots."
  default     = true
}

variable "started" {
  type        = bool
  description = "Whether Terraform should keep the VM started."
  default     = true
}

variable "cpu_cores" {
  type        = number
  description = "CPU cores assigned to the VM."
  default     = 4
}

variable "cpu_type" {
  type        = string
  description = "Proxmox CPU type."
  default     = "host"
}

variable "memory_mb" {
  type        = number
  description = "Memory assigned to the VM in MiB."
  default     = 8192
}

variable "datastore_id" {
  type        = string
  description = "Proxmox datastore for the VM disk."
}

variable "disk_size_gb" {
  type        = number
  description = "Root disk size in GiB."
  default     = 80
}

variable "disk_file_format" {
  type        = string
  description = "Disk file format, for example raw or qcow2."
  default     = "raw"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge."
  default     = "vmbr0"
}

variable "vlan_id" {
  type        = number
  description = "Optional VLAN ID. Use null for untagged traffic."
  default     = null
}

variable "cloud_init_datastore_id" {
  type        = string
  description = "Datastore for cloud-init snippets."
}

variable "cloud_init_username" {
  type        = string
  description = "Initial SSH username created by cloud-init."
  default     = "jam"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the SSH public key injected by cloud-init."
}

variable "ipv4_address" {
  type        = string
  description = "Static IPv4 address assigned to the VM."
}

variable "ipv4_prefix_length" {
  type        = number
  description = "IPv4 CIDR prefix length."
  default     = 24
}

variable "ipv4_gateway" {
  type        = string
  description = "IPv4 default gateway."
}

variable "dns_domain" {
  type        = string
  description = "DNS search domain."
  default     = null
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers."
  default     = []
}
