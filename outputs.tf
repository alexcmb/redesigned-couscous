output "control_plane_public_ip" {
  description = "IP publique du Control Plane"
  value       = azurerm_public_ip.cp_pip.ip_address
}

output "worker_public_ips" {
  description = "IPs publiques des Workers"
  value       = azurerm_public_ip.worker_pip[*].ip_address
}

output "ssh_private_key" {
  description = "Clé privée SSH pour se connecter aux VMs (à sauvegarder dans un fichier .pem)"
  value       = tls_private_key.ssh.private_key_openssh
  sensitive   = true
}

output "ssh_command_cp" {
  description = "Commande pour se connecter en SSH au Control Plane"
  value       = "ssh -i id_rsa ${var.admin_username}@${azurerm_public_ip.cp_pip.ip_address}"
}

output "kubectl_config_command" {
  description = "Commande pour récupérer le kubeconfig depuis le Control Plane"
  value       = "ssh -i id_rsa ${var.admin_username}@${azurerm_public_ip.cp_pip.ip_address} 'sudo cat /etc/kubernetes/admin.conf' > kubeconfig.yaml"
}

output "admin_username" {
  description = "Nom d'utilisateur SSH utilisé pour les VMs"
  value       = var.admin_username
}

output "kubeadm_token" {
  description = "Token bootstrap kubeadm du cluster"
  value       = local.kubeadm_token
  sensitive   = true
}

output "kubeadm_join_command" {
  description = "Commande kubeadm join pour ajouter un noeud manuellement"
  value       = "kubeadm join ${azurerm_network_interface.cp_nic.private_ip_address}:6443 --token ${local.kubeadm_token} --discovery-token-unsafe-skip-ca-verification"
  sensitive   = true
}
