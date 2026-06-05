resource "proxmox_virtual_environment_vm" "this" {
  name            = var.name
  description     = var.description
  node_name       = var.proxmox_node_name
  vm_id           = var.vm_id
  tags            = var.tags
  on_boot         = var.on_boot
  started         = var.started
  stop_on_destroy = true

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = var.agent_enabled
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = var.disk_file_format
  }

  dynamic "disk" {
    for_each = var.data_disk_size_gb == null ? [] : [var.data_disk_size_gb]

    content {
      datastore_id = coalesce(var.data_disk_datastore_id, var.datastore_id)
      interface    = "scsi1"
      size         = disk.value
      file_format  = var.data_disk_file_format
    }
  }

  network_device {
    bridge      = var.network_bridge
    vlan_id     = var.vlan_id
    mac_address = var.mac_address
  }
}
