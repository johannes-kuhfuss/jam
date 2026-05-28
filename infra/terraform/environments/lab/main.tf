module "k3s_node" {
  source = "../../modules/servers/proxmox-vm"

  name                    = var.k3s_node_name
  description             = "jam lab single-node K3s server."
  proxmox_node_name       = var.proxmox_node_name
  vm_id                   = var.k3s_node_vm_id
  template_vm_id          = var.template_vm_id
  tags                    = ["jam", "k3s", "lab"]
  cpu_cores               = var.k3s_node_cpu_cores
  memory_mb               = var.k3s_node_memory_mb
  datastore_id            = var.datastore_id
  disk_size_gb            = var.k3s_node_disk_size_gb
  network_bridge          = var.network_bridge
  vlan_id                 = var.vlan_id
  cloud_init_datastore_id = var.cloud_init_datastore_id
  cloud_init_username     = var.cloud_init_username
  ssh_public_key_path     = var.ssh_public_key_path
  ipv4_address            = var.k3s_node_ipv4_address
  ipv4_prefix_length      = var.ipv4_prefix_length
  ipv4_gateway            = var.ipv4_gateway
  dns_domain              = var.dns_domain
  dns_servers             = var.dns_servers
}
