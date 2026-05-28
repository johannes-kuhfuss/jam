variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint, for example https://pve.example.lan:8006/api2/json."
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token in user@realm!token=value format."
  sensitive   = true
}

variable "proxmox_insecure" {
  type        = bool
  description = "Allow insecure TLS for the Proxmox API."
  default     = false
}

variable "proxmox_node_name" {
  type        = string
  description = "Proxmox node that will host the VM."
}

variable "template_vm_id" {
  type        = number
  description = "Cloud-init template VM ID to clone."
}

variable "datastore_id" {
  type        = string
  description = "Datastore for the VM root disk."
}

variable "cloud_init_datastore_id" {
  type        = string
  description = "Datastore for cloud-init snippets."
}

variable "network_bridge" {
  type        = string
  description = "Proxmox bridge for the VM network interface."
  default     = "vmbr0"
}

variable "vlan_id" {
  type        = number
  description = "Optional VLAN ID. Use null for untagged traffic."
  default     = null
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

variable "k3s_node_name" {
  type        = string
  description = "K3s node VM name."
  default     = "jam-k3s-01"
}

variable "k3s_node_vm_id" {
  type        = number
  description = "Proxmox VM ID for the K3s node."
}

variable "k3s_node_cpu_cores" {
  type        = number
  description = "CPU cores assigned to the K3s node."
  default     = 4
}

variable "k3s_node_memory_mb" {
  type        = number
  description = "Memory assigned to the K3s node in MiB."
  default     = 8192
}

variable "k3s_node_disk_size_gb" {
  type        = number
  description = "Root disk size for the K3s node in GiB."
  default     = 80
}

variable "k3s_node_ipv4_address" {
  type        = string
  description = "Static IPv4 address assigned to the K3s node."
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
