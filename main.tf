terraform {
  required_version = ">= 1.5"

  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    virtual_machine {
      skip_shutdown_and_force_delete = true
    }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}_RG_1"
  location = var.location
}

# Token kubeadm au format <6 chars>.<16 chars>
resource "random_string" "kubeadm_token_id" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "random_string" "kubeadm_token_secret" {
  length  = 16
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  kubeadm_token = "${random_string.kubeadm_token_id.result}.${random_string.kubeadm_token_secret.result}"
}
