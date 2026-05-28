output "name" {
  value       = proxmox_virtual_environment_vm.this.name
  description = "VM name."
}

output "vm_id" {
  value       = proxmox_virtual_environment_vm.this.vm_id
  description = "Proxmox VM ID."
}

output "ipv4_address" {
  value       = var.ipv4_address
  description = "Configured VM IPv4 address."
}
