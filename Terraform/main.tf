resource "azurerm_resource_group" "RG" {
  name     = "server_hardening_RG1"
  location = var.location

}
data "azurerm_client_config" "current" {}
resource "azurerm_virtual_network" "SRV_HRD_VNT1" {

  name                = "SRV_HRD_VNT1"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  address_space       = ["10.0.0.16/24"]

}

resource "azurerm_subnet" "SUB" {

  name                 = "Sub1"
  address_prefixes     = ["10.0.0.1/28"]
  virtual_network_name = "azurerm_virtual_network.SRV_HRD_VNT1.name"
  resource_group_name  = azurerm_resource_group.RG.name
}

resource "azurerm_linux_virtual_machine" "VM" {
  name                  = "UBVMRVHRD"
  resource_group_name   = azurerm_resource_group.RG.name
  network_interface_ids = [azurerm_network_interface.VMNIC.id]
  location              = azurerm_resource_group.RG.location
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }


  size = "Standard_B1s"
  admin_username = "azureuser"
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh


  }
  identity {
    type = "SystemAssigned"
  }

}
data "azurerm_role_definition" "contributor" {
  name = "Contributor"

}


resource "azurerm_network_interface" "VMNIC" {
  name                = "MNIC"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SUB.id
    private_ip_address_allocation = "Dynamic"

  }


}

resource "azurerm_network_security_group" "NSG" {
  name                = "NS"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
}

resource "azurerm_network_security_rule" "NSGRULE" {
  name                        = "NSGRULE"
  resource_group_name         = azurerm_resource_group.RG.name
  network_security_group_name = azurerm_network_security_group.NSG.name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "116.68.78.47/32"
  destination_address_prefix  = "*"

}

resource "azurerm_key_vault" "KV" {
  name                       = "KVSRVHRD"
  resource_group_name        = azurerm_resource_group.RG.name
  location                   = azurerm_resource_group.RG.location
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
}


resource "azurerm_role_assignment" "linux_vm_kv_role" {
  scope                = azurerm_key_vault.KV.id
  principal_id         = azurerm_linux_virtual_machine.VM.identity[0].principal_id
  role_definition_name = "Key Vault Administrator"
}
resource "azurerm_role_assignment" "terraform_user_kv_role" {
  scope                = azurerm_key_vault.KV.id
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Secrets Officer"
}

