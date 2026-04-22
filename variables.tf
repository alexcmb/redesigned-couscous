variable "prefix" {
  description = "Préfixe utilisé pour nommer toutes les ressources"
  type        = string
  default     = "ACA"
}

variable "location" {
  description = "Région Azure où déployer les ressources"
  type        = string
  default     = "France Central"
}

variable "worker_count" {
  description = "Nombre de noeuds Worker à déployer"
  type        = number
  default     = 2
}

variable "vm_size_wn" {
  description = "Taille des machines virtuelles"
  type        = string
  default     = "Standard_B1ms"
}

variable "vm_size" {
  description = "Taille des machines virtuelles"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Nom d'utilisateur administrateur des VMs"
  type        = string
  default     = "adminuser"
}

variable "pod_network_cidr" {
  description = "CIDR du réseau Pod Kubernetes (utilisé par kubeadm/flannel)"
  type        = string
  default     = "10.244.0.0/16"
}
