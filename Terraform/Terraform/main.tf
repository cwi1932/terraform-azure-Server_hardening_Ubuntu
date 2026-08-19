resource "azurerm_resource_group" "RG" {
     name = server_hardening_RG1
     location =var.Location

}

resource "azurerm_virtual_network" "SRV_HRD_VNT1" {

          name = SRV_HRD_VNT1
          resource_group_name= azurerm_resource_group.RG.name
          location = azurerm_resource_group.RG.Location
          address_space = ["10.0.0.16/24"]

  }        

resource "azurerm_subnet" "SUB" {

          name = "Sub1"
          address_prefixes= ["10.0.0.1/28"]
          virtual_network_name = "azurerm_virtual_network.SRV_HRD_VNT1.name"
          resource_group_name = "azurerm_resource_group.RG.name"
  }

 resource "azurerm_linux_virtual_machine" "VM" {
      name = UB_VM_SRV_HRD
      resource_group_name = "azurem_resource_group_RG.name"
      network_interface_ids = azureerm_virtual_network_interface.VMNIC.id
      location = azurerm_resource_group.RG.Location
      os_disk {
      caching = "ReadWrite"
      storage_account_type = "Standard_LRS"
      }
     
      size    = "Standard_B1s"
      admin_ssh_key {
     username = "adminuser"
     public_key = tls_private_key.ssh.public_key_openssh
     
 }
  identity {
    type = "SystemAssigned"
  }
  
 }
 data "azurerm_role_definition" "contributor" {
  name = "Contributor"
  
}


resource "azurerm_network_interface"  "VMNIC"{
         name = MNIC
         resource_group_name = "azurem_resource_group_RG.name"
         location = azurerm_resource_group.RG.Location

ip_configuration {
        name = "internal"
        subnet_id=azurerm_subnet.SUB.id
        private_ip_address_allocation = "Dynamic"
 }


}

resource "azurerm_network security_group" "NSG" {
         name = NSG
         resource_group_name = "azurem_resource_group_RG.name"
         location = azurerm_resource_group.RG.Location

resource "azurerm_network_security_rule" "NSGRULE" {
         name = NSGRULE
         resource_group_name = "azurem_resource_group_RG.name"
         network_security_group_name = azurerm_network_security_group.NSG.name
         priority = 100
         direction = "Inbound"
         access = "Allow"
         protocol = "Tcp"
         source_port_range = "116.68.78.47"
         destination_port_range = "22"
         source_address_prefix = "116.68.78.47/32"
         destination_address_prefix = "*"




resource "azurerm_key_vault" "KV" {
         name = KV_SRV_HRD
         resource_group_name = "azurerm_resource_group.RG.name"
         location = azurerm_resource_group.RG.Location
         sku_name = "standard"
         rbac_authorization_enabled = true
         tenant_id = data.azurerm_client_config.current.tenant_id
         soft_delete_retention_days = 7
}


resource "azurerm_role_assignment" "linux_vm_kv_role" {
  scope                = azurerm_key_vault.key_vault.KV.id
  principal_id         = azurerm_linux_virtual_machine.VM.identity[0].principal_id
  role_definition_name = "Key Vault Administrator"
}
resource "azurerm_role_assignment" "terraform_user_kv_role" {
  scope                = azurerm_key_vault.key_vault.id
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Secrets Officer"
}

