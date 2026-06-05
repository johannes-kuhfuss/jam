locals {
  api_endpoint = coalesce(var.api_endpoint, var.api_virtual_ip)

  talos_nodes = {
    for index in range(var.talos_node_count) :
    format("%s-%02d", var.talos_node_name_prefix, index + 1) => {
      index        = index
      vm_id        = var.talos_node_vm_id_start + index
      ipv4_address = var.talos_node_ipv4_addresses[index]
      mac_address  = try(var.talos_node_mac_addresses[index], null)
    }
  }

  node_common_patch = {
    cluster = {
      allowSchedulingOnControlPlanes = true
      network = {
        cni = {
          name = "none"
        }
        podSubnets     = [var.pod_cidr]
        serviceSubnets = [var.service_cidr]
      }
      proxy = {
        disabled = true
      }
    }
    machine = {
      nodeLabels = {
        "node.kubernetes.io/exclude-from-external-load-balancers" = {
          "$patch" = "delete"
        }
      }
      install = merge(
        {
          disk = var.talos_install_disk
        },
        var.talos_installer_image == null ? {} : {
          image = var.talos_installer_image
        }
      )
      kubelet = {
        extraMounts = [
          {
            destination = "/var/mnt/longhorn"
            type        = "bind"
            source      = "/var/mnt/longhorn"
            options     = ["bind", "rshared", "rw"]
          }
        ]
      }
      features = {
        kubePrism = {
          enabled = true
          port    = 7445
        }
      }
    }
  }

  kube_vip_daemonset = {
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    metadata = {
      name      = "kube-vip"
      namespace = "kube-system"
      labels = {
        "app.kubernetes.io/name" = "kube-vip"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "kube-vip"
        }
      }
      template = {
        metadata = {
          labels = {
            "app.kubernetes.io/name" = "kube-vip"
          }
        }
        spec = {
          serviceAccountName = "kube-vip"
          hostNetwork        = true
          tolerations = [
            {
              operator = "Exists"
              effect   = "NoSchedule"
            },
            {
              operator = "Exists"
              effect   = "NoExecute"
            }
          ]
          affinity = {
            nodeAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = {
                nodeSelectorTerms = [
                  {
                    matchExpressions = [
                      {
                        key      = "node-role.kubernetes.io/control-plane"
                        operator = "Exists"
                      }
                    ]
                  }
                ]
              }
            }
          }
          containers = [
            {
              name            = "kube-vip"
              image           = var.kube_vip_image
              imagePullPolicy = "IfNotPresent"
              args            = ["manager"]
              env = [
                { name = "vip_arp", value = "true" },
                { name = "address", value = var.api_virtual_ip },
                { name = "port", value = "6443" },
                { name = "vip_interface", value = var.talos_network_interface },
                { name = "vip_subnet", value = "32" },
                { name = "cp_enable", value = "true" },
                { name = "cp_namespace", value = "kube-system" },
                { name = "svc_enable", value = "false" },
                { name = "vip_leaderelection", value = "true" },
                { name = "vip_leasename", value = "plndr-cp-lock" },
                { name = "vip_leaseduration", value = "5" },
                { name = "vip_renewdeadline", value = "3" },
                { name = "vip_retryperiod", value = "1" }
              ]
              securityContext = {
                capabilities = {
                  add = ["NET_ADMIN", "NET_RAW"]
                }
              }
            }
          ]
        }
      }
    }
  }

  kube_vip_patch = {
    cluster = {
      extraManifests = [
        "https://kube-vip.io/manifests/rbac.yaml"
      ]
      inlineManifests = [
        {
          name     = "kube-vip"
          contents = yamlencode(local.kube_vip_daemonset)
        }
      ]
    }
  }

  longhorn_user_volume_config = {
    apiVersion = "v1alpha1"
    kind       = "UserVolumeConfig"
    name       = "longhorn"
    provisioning = {
      diskSelector = {
        match = var.longhorn_data_disk_selector
      }
      grow    = false
      maxSize = "${var.longhorn_data_disk_size_gb}GiB"
      minSize = "${var.longhorn_data_disk_size_gb}GiB"
    }
    filesystem = {
      type = "xfs"
    }
  }

}

resource "terraform_data" "talos_node_ipv4_address_count_validation" {
  input = {
    talos_node_count          = var.talos_node_count
    talos_node_ipv4_addresses = var.talos_node_ipv4_addresses
  }

  lifecycle {
    precondition {
      condition     = length(var.talos_node_ipv4_addresses) == var.talos_node_count
      error_message = "talos_node_ipv4_addresses must contain exactly talos_node_count addresses."
    }
  }
}

resource "terraform_data" "talos_node_mac_address_count_validation" {
  input = {
    talos_node_count         = var.talos_node_count
    talos_node_mac_addresses = var.talos_node_mac_addresses
  }

  lifecycle {
    precondition {
      condition     = length(var.talos_node_mac_addresses) == 0 || length(var.talos_node_mac_addresses) == var.talos_node_count
      error_message = "talos_node_mac_addresses must be empty or contain exactly talos_node_count addresses."
    }
  }
}

module "talos_nodes" {
  source   = "../../modules/servers/proxmox-talos-vm"
  for_each = local.talos_nodes

  depends_on = [
    terraform_data.talos_node_ipv4_address_count_validation,
    terraform_data.talos_node_mac_address_count_validation
  ]

  name              = each.key
  description       = "jam lab Talos control-plane node."
  proxmox_node_name = var.proxmox_node_name
  vm_id             = each.value.vm_id
  template_vm_id    = var.template_vm_id
  tags              = ["jam", "talos", "lab"]
  cpu_cores         = var.talos_node_cpu_cores
  memory_mb         = var.talos_node_memory_mb
  datastore_id      = var.datastore_id
  disk_size_gb      = var.talos_node_disk_size_gb
  data_disk_size_gb = var.longhorn_data_disk_size_gb
  network_bridge    = var.network_bridge
  vlan_id           = var.vlan_id
  mac_address       = each.value.mac_address
  agent_enabled     = var.talos_qemu_agent_enabled
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${local.api_endpoint}:6443"
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = local.talos_nodes

  depends_on = [module.talos_nodes]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.ipv4_address

  config_patches = [
    yamlencode(local.node_common_patch),
    yamlencode(local.kube_vip_patch),
    yamlencode(local.longhorn_user_volume_config),
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = var.talos_network_interface
              dhcp      = false
              addresses = ["${each.value.ipv4_address}/${var.ipv4_prefix_length}"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.ipv4_gateway
                }
              ]
            }
          ]
          nameservers = var.dns_servers
          searchDomains = compact([
            var.dns_domain
          ])
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  node                 = var.talos_node_ipv4_addresses[0]
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = var.talos_node_ipv4_addresses
  endpoints            = var.talos_node_ipv4_addresses
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.talos_node_ipv4_addresses[0]
  endpoint             = var.talos_node_ipv4_addresses[0]
}
