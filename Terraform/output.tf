output "backendA_private_ip" {
  description = "Private IP of backend VM A"
  value       = azurerm_network_interface.VMNIC1.private_ip_address
}
output "backendB_private_ip" {
  value = azurerm_network_interface.VMNIC2.private_ip_address
}
output "ssh_private_key" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}