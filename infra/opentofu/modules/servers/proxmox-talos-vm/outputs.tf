output "name" {
  value       = proxmox_virtual_environment_vm.this.name
  description = "VM name."
}

output "vm_id" {
  value       = proxmox_virtual_environment_vm.this.vm_id
  description = "Proxmox VM ID."
}

output "mac_address" {
  value       = var.mac_address
  description = "Configured VM MAC address."
}
