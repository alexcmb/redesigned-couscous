variable "prefix" {
  description = "Préfixe utilisé pour nommer toutes les ressources"
  type        = string
  default     = "ACA"
}

variable "location" {
  description = "Région Azure où déployer les ressources"
  type        = string
  default     = "west europe"
}

variable "worker_count" {
  description = "Nombre de noeuds Worker à déployer"
  type        = number
  default     = 2
}

variable "vm_size_wn" {
  description = "Taille des machines virtuelles"
  type        = string
  default     = "Standard_d2s_v3"
}

variable "vm_size" {
  description = "Taille des machines virtuelles"
  type        = string
  default     = "Standard_d2s_v3"
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

variable "tfstate_container_name" {
  description = "Nom du container Blob Azure qui stocke le tfstate"
  type        = string
  default     = "tfstate"
}
