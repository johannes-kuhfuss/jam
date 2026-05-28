output "k3s_node_name" {
  value       = values(module.k3s_nodes)[0].name
  description = "First K3s node VM name."
}

output "k3s_node_vm_id" {
  value       = values(module.k3s_nodes)[0].vm_id
  description = "First K3s node Proxmox VM ID."
}

output "k3s_node_ipv4_address" {
  value       = values(module.k3s_nodes)[0].ipv4_address
  description = "First K3s node IPv4 address."
}

output "k3s_nodes" {
  value = [
    for name, node in module.k3s_nodes : {
      name         = node.name
      vm_id        = node.vm_id
      ipv4_address = node.ipv4_address
    }
  ]
  description = "K3s nodes created for the lab cluster."
}

output "ssh_user" {
  value       = var.cloud_init_username
  description = "Cloud-init SSH username."
}

output "ansible_inventory_hint" {
  value = [
    for node in values(module.k3s_nodes) :
    "${node.name} ansible_host=${node.ipv4_address} ansible_user=${var.cloud_init_username}"
  ]
  description = "Inventory lines to copy into the lab Ansible inventory."
}
