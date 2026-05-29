locals {
  k3s_nodes = {
    for index in range(var.k3s_node_count) :
    format("%s-%02d", var.k3s_node_name_prefix, index + 1) => {
      index        = index
      vm_id        = var.k3s_node_vm_id_start + index
      ipv4_address = try(var.k3s_node_ipv4_addresses[index], null)
    }
  }
}

resource "terraform_data" "k3s_node_ipv4_address_count_validation" {
  input = {
    k3s_node_count          = var.k3s_node_count
    k3s_node_ipv4_addresses = var.k3s_node_ipv4_addresses
  }

  lifecycle {
    precondition {
      condition     = length(var.k3s_node_ipv4_addresses) == var.k3s_node_count
      error_message = "k3s_node_ipv4_addresses must contain exactly k3s_node_count addresses."
    }
  }
}

module "k3s_nodes" {
  source   = "../../modules/servers/proxmox-vm"
  for_each = local.k3s_nodes

  depends_on = [terraform_data.k3s_node_ipv4_address_count_validation]

  name                    = each.key
  description             = "jam lab K3s server."
  proxmox_node_name       = var.proxmox_node_name
  vm_id                   = each.value.vm_id
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
  ipv4_address            = each.value.ipv4_address
  ipv4_prefix_length      = var.ipv4_prefix_length
  ipv4_gateway            = var.ipv4_gateway
  dns_domain              = var.dns_domain
  dns_servers             = var.dns_servers
}
