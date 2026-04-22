# Clé SSH générée par Terraform (à usage POC)
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# --- CONTROL PLANE ---

resource "azurerm_public_ip" "cp_pip" {
  name                = "${var.prefix}_PIP_CP_1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "cp_nic" {
  name                = "${var.prefix}_NIC_CP_1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cp_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "cp_vm" {
  name                = "${var.prefix}-VM-CP-1"
  computer_name       = replace("${var.prefix}-VM-CP-1", "_", "-")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  priority            = "Spot"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.cp_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init/control-plane.yaml", {
    kubeadm_token            = local.kubeadm_token
    control_plane_private_ip = azurerm_network_interface.cp_nic.private_ip_address
    admin_username           = var.admin_username
    pod_network_cidr         = var.pod_network_cidr
  }))
}

# --- WORKERS ---

resource "azurerm_public_ip" "worker_pip" {
  count               = var.worker_count
  name                = "${var.prefix}_PIP_WORKER_${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "worker_nic" {
  count               = var.worker_count
  name                = "${var.prefix}_NIC_WORKER_${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.worker_pip[count.index].id
  }
}

resource "azurerm_linux_virtual_machine" "worker_vm" {
  count               = var.worker_count
  name                = "${var.prefix}-VM-WORKER-${count.index + 1}"
  computer_name       = replace("${var.prefix}-VM-WORKER-${count.index + 1}", "_", "-")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size_wn
  priority            = "Spot"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.worker_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init/worker.yaml", {
    kubeadm_token            = local.kubeadm_token
    control_plane_private_ip = azurerm_network_interface.cp_nic.private_ip_address
  }))

  depends_on = [
    azurerm_linux_virtual_machine.cp_vm
  ]
}
