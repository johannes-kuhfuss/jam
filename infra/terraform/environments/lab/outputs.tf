output "k3s_node_name" {
  value       = module.k3s_node.name
  description = "K3s node VM name."
}

output "k3s_node_vm_id" {
  value       = module.k3s_node.vm_id
  description = "K3s node Proxmox VM ID."
}

output "k3s_node_ipv4_address" {
  value       = module.k3s_node.ipv4_address
  description = "K3s node IPv4 address."
}

output "ssh_user" {
  value       = var.cloud_init_username
  description = "Cloud-init SSH username."
}

output "ansible_inventory_hint" {
  value       = "${var.k3s_node_name} ansible_host=${module.k3s_node.ipv4_address} ansible_user=${var.cloud_init_username}"
  description = "Inventory line to copy into the lab Ansible inventory."
}
