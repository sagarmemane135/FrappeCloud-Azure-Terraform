resource "azurerm_dns_zone" "root_zone" {
  name                = var.root_domain
  resource_group_name = azurerm_resource_group.rg.name
}

# Record for the Dashboard/Control node
resource "azurerm_dns_a_record" "dashboard" {
  name                = "dashboard"
  zone_name           = azurerm_dns_zone.root_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_public_ip.pip["press-control"].ip_address]
}

# Wildcard record pointing to the Proxy node
resource "azurerm_dns_a_record" "wildcard" {
  name                = "*"
  zone_name           = azurerm_dns_zone.root_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_public_ip.pip["proxy-node"].ip_address]
}