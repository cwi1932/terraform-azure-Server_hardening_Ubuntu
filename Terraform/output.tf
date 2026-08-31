output "Azurerm_linux_virtual_machine_name" {
  
  description = "The name of the backend virtual machine A."
  value       = {
   linux_vm_name = azurerm_linux_virtual_machine.VMB-BackendA.name
    network_interface = azurerm_network_interface.VMNIC1.private_ip_address
  
}
}
output "Azurerm_linux_virtual_machine_details" {

  description = "Details of the backend virtual machines B."

  value = {
    linux_vm_name     = azurerm_linux_virtual_machine.VMB-BackendB.name
    network_interface = azurerm_network_interface.VMNIC2.private_ip_address
  }
}