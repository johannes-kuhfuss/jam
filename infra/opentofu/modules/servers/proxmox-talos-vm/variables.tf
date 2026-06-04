variable "name" {
  type        = string
  description = "VM name."
}

variable "description" {
  type        = string
  description = "VM description."
  default     = "Managed by OpenTofu."
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
  description = "Talos template VM ID to clone."
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
  description = "Whether OpenTofu should keep the VM started."
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

variable "mac_address" {
  type        = string
  description = "Optional static MAC address for DHCP reservation and first Talos maintenance contact."
  default     = null
}

variable "agent_enabled" {
  type        = bool
  description = "Enable the QEMU guest agent when the Talos image includes the guest agent extension."
  default     = false
}
