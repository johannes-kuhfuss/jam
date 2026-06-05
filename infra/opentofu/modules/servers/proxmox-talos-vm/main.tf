resource "proxmox_virtual_environment_vm" "this" {
  name            = var.name
  description     = var.description
  node_name       = var.proxmox_node_name
  vm_id           = var.vm_id
  tags            = var.tags
  on_boot         = var.on_boot
  started         = var.started
  stop_on_destroy = true
  bios            = var.bios
  machine         = var.machine
  scsi_hardware   = var.scsi_hardware
  boot_order      = ["scsi0"]

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
    floating  = 0
  }

  dynamic "efi_disk" {
    for_each = var.bios == "ovmf" ? [1] : []

    content {
      datastore_id      = coalesce(var.efi_disk_datastore_id, var.datastore_id)
      file_format       = var.efi_disk_file_format
      type              = var.efi_disk_type
      pre_enrolled_keys = var.efi_disk_pre_enrolled_keys
    }
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = var.disk_file_format
    cache        = var.disk_cache
    discard      = var.disk_discard
    ssd          = var.disk_ssd
  }

  dynamic "disk" {
    for_each = var.data_disk_size_gb == null ? [] : [var.data_disk_size_gb]

    content {
      datastore_id = coalesce(var.data_disk_datastore_id, var.datastore_id)
      interface    = "scsi1"
      size         = disk.value
      file_format  = var.data_disk_file_format
      cache        = var.data_disk_cache
      discard      = var.data_disk_discard
      ssd          = var.data_disk_ssd
    }
  }

  network_device {
    bridge      = var.network_bridge
    vlan_id     = var.vlan_id
    mac_address = var.mac_address
    model       = "virtio"
  }

  serial_device {
    device = "socket"
  }
}
