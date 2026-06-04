terraform {
  required_version = ">= 1.8.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11"
    }
  }
}
