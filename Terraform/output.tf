output "backendA_private_ip" {
  description = "Private IP of backend VM A"
  value       = azurerm_network_interface.VMNIC1.private_ip_address
}

output "backendB_private_ip" {
  description = "Private IP of backend VM B"
  value       = azurerm_network_interface.VMNIC2.private_ip_address
}
