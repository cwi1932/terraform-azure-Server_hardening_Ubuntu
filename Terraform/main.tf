resource "azurerm_resource_group" "RG" {
  name     = "server_hardening_RG1"
  location = var.Location

}
data "azurerm_client_config" "current" {
}

resource "random_password" "windows_admin_password" {

length = 16
special = true
override_special = "!#$%&*()-_=+[]{}<>:?"
min_upper = 1
min_lower = 1
min_numeric = 1
min_special = 1

}


resource "azurerm_virtual_network" "SRV_HRD_VNT1" {

  name                = "SRV_HRD_VNT1"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  address_space       = ["10.0.0.0/16"]

}

resource "azurerm_subnet" "SUBA" {

  name                 = "Sub1"
  address_prefixes     = ["10.0.0.1/28"]
  virtual_network_name = azurerm_virtual_network.SRV_HRD_VNT1.name
  resource_group_name  = azurerm_resource_group.RG.name
 
}

resource "azurerm_subnet" "SUBB" {

  name                 = "Sub2"
  address_prefixes     = ["10.10.0.2/28"]
  virtual_network_name = azurerm_virtual_network.SRV_HRD_VNT1.name
  resource_group_name  = azurerm_resource_group.RG.name
}

resource "azurerm_public_ip" "Standard_LB_IP" {
  name                = "PublicIPForLB"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "PLB" {
  name = var.load_balancer_name
  resource_group_name = azurerm_resource_group.RG.name
  location = azurerm_resource_group.RG.location
   sku = "Standard"   
   frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.Standard_LB_IP.id
  }
}

resource "azurerm_lb_rule" "LB_rule" {
  loadbalancer_id                = azurerm_lb.PLB.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_probe" "probe_LB" {
  loadbalancer_id = azurerm_lb.PLB.id
  protocol           = "Http"
  name            = "http-running-probe"
  port            = 80
  request_path = "/"
}
resource "azurerm_lb_backend_address_pool" "backend_pool_LB_name" {
  loadbalancer_id = azurerm_lb.PLB.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_nat_rule" "LB_nat_rule1" {
  resource_group_name = azurerm_resource_group.RG.name
  loadbalancer_id    = azurerm_lb.PLB.id
  name = "LBnatrule1"
  protocol = "Tcp"
  frontend_port_start              = 3000
  frontend_port_end                = 3500
  backend_port = 80
  backend_address_pool_id        = azurerm_lb_backend_address_pool.backend_pool_LB_name.id
  frontend_ip_configuration_name = "PublicIPAddress"
  
}

resource "azurerm_lb_nat_rule" "LB_nat_rule2" {
  resource_group_name = azurerm_resource_group.RG.name
  loadbalancer_id    = azurerm_lb.PLB.id
  name = "LBnatrule2"
  protocol = "Tcp"
  frontend_port_start              = 4000
  frontend_port_end                = 4500
  backend_port = 443
  backend_address_pool_id        = azurerm_lb_backend_address_pool.backend_pool_LB_name.id
  frontend_ip_configuration_name = "PublicIPAddress"
  
}
resource "azurerm_lb_nat_rule" "Linux_backendVM_LB_nat_rule" {
  resource_group_name = azurerm_resource_group.RG.name
  loadbalancer_id    = azurerm_lb.PLB.id
  name = "LBnatrul3"
  protocol = "Tcp"
  frontend_port_start = 500
  frontend_port_end = 1000
  backend_port = 22
  backend_address_pool_id        = azurerm_lb_backend_address_pool.backend_pool_LB_name.id
  frontend_ip_configuration_name = "PublicIPAddress"
  
}


resource "azurerm_lb_backend_address_pool_address" "backend_pool_LB_IP_backendA" {
  name                    = "backedendA"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool_LB_name.id
  virtual_network_id      = azurerm_virtual_network.SRV_HRD_VNT1.id
  ip_address = azurerm_network_interface.VMNIC1.private_ip_address
}

resource "azurerm_lb_backend_address_pool_address" "backend_pool_LB_IP_backendB" {
  name                    = "backedendB"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool_LB_name.id
  virtual_network_id      = azurerm_virtual_network.SRV_HRD_VNT1.id
  ip_address = azurerm_network_interface.VMNIC2.private_ip_address
}
resource "azurerm_lb_outbound_rule" "outbound_rule_LB" {
  
  name = "OutboundRule"
    loadbalancer_id = azurerm_lb.PLB.id
    protocol        = "Tcp"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool_LB_name.id
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    

  }
}
 

resource "azurerm_linux_virtual_machine" "VMB-BackendA" {
  name                  = "UB_VM_SRV_backendA"
  resource_group_name   = azurerm_resource_group.RG.name
  network_interface_ids = [azurerm_network_interface.VMNIC1.id]
  location              = azurerm_resource_group.RG.location
  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.ssh.public_key_openssh

  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
  size = "Standard_B1s"
   admin_username = "adminuser"

  identity {
    type = "SystemAssigned"
  }

}


resource "azurerm_linux_virtual_machine" "VMB-BackendB" {
  name                  = "UB_VM_SRV_backendB"
  resource_group_name   = azurerm_resource_group.RG.name
  network_interface_ids = [azurerm_network_interface.VMNIC2.id]
  location              = azurerm_resource_group.RG.location
  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.ssh.public_key_openssh

  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
  size = "Standard_B1s"
   admin_username = "adminuser"

  identity {
    type = "SystemAssigned"
  }

}

resource "azurerm_mssql_server" "AzSQLPaaSDB" {
  name = "azsqlsrv"
  resource_group_name = azurerm_resource_group.RG.name
  location = azurerm_resource_group.RG.location
  version = "12.0"
  administrator_login          = "missadministrator"
  administrator_login_password = "azurerm_key_vault_secret.windows_admin_password.value"
  minimum_tls_version          = "1.2"
  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = "5a99f7b1-a653-4bba-b5bb-21fc29b06f46"
  }
identity {
    type = "SystemAssigned"
  }
  tags = {
    environment = "production"
  }
}

resource "azurerm_network_interface" "VMNIC1" {
  name                = "MNIC"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SUBA.id
    private_ip_address_allocation = "Dynamic"
  }


}

resource "azurerm_network_interface" "VMNIC2" {
  name                = "MNIC"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SUBB.id
    private_ip_address_allocation = "Dynamic"
  }


}

resource "azurerm_network_security_group" "NSG" {
  name                = "NSG12"
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
    source_port_range           = "116.68.78.47"
    destination_port_range      = "22"
    source_address_prefix       = "116.68.78.47/32"
    destination_address_prefix  = "*"

  }

resource "azurerm_subnet_network_security_group_association" "NSGASSOCA" {
  subnet_id                 = azurerm_subnet.SUBA.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}


resource "azurerm_subnet_network_security_group_association" "NSGASSOCB" {
  subnet_id                 = azurerm_subnet.SUBB.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}

resource "azurerm_key_vault" "KV" {
  name                       = "KV-SRV-HRD"
  resource_group_name        = azurerm_resource_group.RG.name
  location                   = azurerm_resource_group.RG.location
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7

}

resource "azurerm_key_vault_secret" "windows_admin_password" {
  name         = "windows-admin-password"
  value        = random_password.windows_admin_password.result
  key_vault_id = azurerm_key_vault.KV.id
  depends_on = [
    azurerm_role_assignment.MssqlServer_kv_role
  ]
}
resource "azurerm_role_assignment" "backendA_kv_role" {
  scope                = azurerm_key_vault.KV.id
  principal_id         = azurerm_linux_virtual_machine.VMB-BackendA.identity[0].principal_id
  role_definition_name = "Key Vault Secrets User"
}

resource "azurerm_role_assignment" "backendB_kv_role" {
  scope                = azurerm_key_vault.KV.id
  principal_id         = azurerm_linux_virtual_machine.VMB-BackendB.identity[0].principal_id
  role_definition_name = "Key Vault Secrets User"
}
resource "azurerm_role_assignment" "MssqlServer_kv_role" {
  scope                = azurerm_key_vault.KV.id
  principal_id         = azurerm_mssql_server.AzSQLPaaSDB.identity[0].principal_id
  role_definition_name = "Key Vault Secrets Officer"
}

resource "azurerm_private_dns_zone" "pvszone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "pvlink" {
  name                  = "pv-vnetA-link"
  resource_group_name   = azurerm_resource_group.RG.name
  private_dns_zone_name = azurerm_private_dns_zone.pvszone.name
  virtual_network_id    = azurerm_virtual_network.SRV_HRD_VNT1.id

  registration_enabled = true

  # FORCE ISOLATION ORDER
  depends_on = [
    azurerm_private_dns_zone.pvszone
  ]
}
