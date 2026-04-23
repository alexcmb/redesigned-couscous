data "azurerm_client_config" "current" {}

locals {
  key_vault_name_prefix = replace(lower(var.prefix), "/[^a-z0-9]/", "")
}

resource "random_string" "ssh_kv_suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_key_vault" "ssh" {
  name                        = substr("kv${local.key_vault_name_prefix}${random_string.ssh_kv_suffix.result}", 0, 24)
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set",
    ]
  }
}

resource "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "ssh-private-key"
  value        = tls_private_key.ssh.private_key_openssh
  key_vault_id = azurerm_key_vault.ssh.id
}