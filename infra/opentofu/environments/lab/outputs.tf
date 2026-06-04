output "talos_nodes" {
  value = [
    for name, node in local.talos_nodes : {
      name         = name
      vm_id        = node.vm_id
      ipv4_address = node.ipv4_address
      mac_address  = node.mac_address
    }
  ]
  description = "Talos nodes created for the lab cluster."
}

output "kubernetes_api_endpoint" {
  value       = "https://${local.api_endpoint}:6443"
  description = "Kubernetes API endpoint configured in the Talos cluster."
}

output "talosconfig" {
  value       = data.talos_client_configuration.this.talos_config
  description = "Generated talosconfig. Store securely."
  sensitive   = true
}

output "kubeconfig" {
  value       = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  description = "Generated Kubernetes kubeconfig. Store securely."
  sensitive   = true
}

output "talos_node_ips" {
  value       = var.talos_node_ipv4_addresses
  description = "Talos node IP addresses."
}

output "cilium_bootstrap_hint" {
  value       = "Run scripts/dev/bootstrap-cilium.sh after tofu apply and kubeconfig retrieval."
  description = "Next step for Cilium bootstrap."
}
