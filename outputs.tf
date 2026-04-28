output "dashboard_ip" {
  value = azurerm_public_ip.pip["press-control"].ip_address
}

output "proxy_ip" {
  value = azurerm_public_ip.pip["proxy-node"].ip_address
}

output "storage_account_name" {
  value = azurerm_storage_account.backups.name
}

output "name_servers" {
  description = "Update these at your domain registrar"
  value       = azurerm_dns_zone.root_zone.name_servers
}

output "nat_gateway_public_ip" {
  description = "Outbound egress IP used by private nodes via NAT Gateway"
  value       = azurerm_public_ip.nat_ip.ip_address
}