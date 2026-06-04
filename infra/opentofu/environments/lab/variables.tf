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
  description = "Talos template VM ID to clone."
}

variable "datastore_id" {
  type        = string
  description = "Datastore for the VM root disk."
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

variable "cluster_name" {
  type        = string
  description = "Talos/Kubernetes cluster name."
  default     = "jam-lab"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for Talos to deploy."
  default     = "v1.35.4"
}

variable "talos_version" {
  type        = string
  description = "Talos machine configuration version contract. This should match the Talos template version family."
  default     = "v1.12"
}

variable "talos_node_count" {
  type        = number
  description = "Number of converged Talos control-plane nodes. Supported values are 1 and 3."
  default     = 1

  validation {
    condition     = contains([1, 3], var.talos_node_count)
    error_message = "talos_node_count must be either 1 or 3."
  }
}

variable "talos_node_name_prefix" {
  type        = string
  description = "Prefix used for Talos node VM names."
  default     = "jam-talos"
}

variable "talos_node_vm_id_start" {
  type        = number
  description = "Starting Proxmox VM ID for Talos nodes. Additional nodes increment from this value."
}

variable "talos_node_cpu_cores" {
  type        = number
  description = "CPU cores assigned to each Talos node."
  default     = 4
}

variable "talos_node_memory_mb" {
  type        = number
  description = "Memory assigned to each Talos node in MiB."
  default     = 8192
}

variable "talos_node_disk_size_gb" {
  type        = number
  description = "Root disk size for each Talos node in GiB."
  default     = 80
}

variable "talos_qemu_agent_enabled" {
  type        = bool
  description = "Enable QEMU guest agent support when the Talos Image Factory schematic includes siderolabs/qemu-guest-agent."
  default     = false
}

variable "talos_node_ipv4_addresses" {
  type        = list(string)
  description = "Final static IPv4 addresses assigned by Talos machine config. Provide one address for single-node mode or three for redundant mode."

  validation {
    condition     = contains([1, 3], length(var.talos_node_ipv4_addresses))
    error_message = "talos_node_ipv4_addresses must contain either one address or three addresses."
  }
}

variable "talos_node_mac_addresses" {
  type        = list(string)
  description = "Optional static MAC addresses. Use DHCP reservations for first Talos maintenance contact."
  default     = []
}

variable "talos_install_disk" {
  type        = string
  description = "Disk Talos installs itself to."
  default     = "/dev/sda"
}

variable "talos_network_interface" {
  type        = string
  description = "Talos network interface used for static addressing and VIP advertisement."
  default     = "eth0"
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

variable "api_virtual_ip" {
  type        = string
  description = "Free Kubernetes API VIP advertised by kube-vip."
}

variable "api_endpoint" {
  type        = string
  description = "Stable Kubernetes API endpoint DNS name or IP. Defaults to api_virtual_ip."
  default     = null
}

variable "pod_cidr" {
  type        = string
  description = "Kubernetes pod CIDR."
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  type        = string
  description = "Kubernetes service CIDR."
  default     = "10.96.0.0/12"
}

variable "kube_vip_image" {
  type        = string
  description = "kube-vip image used for the Kubernetes API VIP inline manifest."
  default     = "ghcr.io/kube-vip/kube-vip:v0.9.2"
}
