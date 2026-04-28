# Configuration for the 4 specific nodes
locals {
  servers = {
    "press-control" = { size = "Standard_B2s", ip = "10.0.1.10" }
    "proxy-node"    = { size = "Standard_B1s", ip = "10.0.1.11" }
    "nonprod-node"  = { size = "Standard_D2s_v3", ip = "10.0.1.12" }
    "prod-node"     = { size = "Standard_D4s_v3", ip = "10.0.1.13" }
  }

  # Only these nodes are internet-facing.
  public_nodes = toset(["press-control", "proxy-node"])
}

# Terraform-managed key used by press-control to SSH into worker nodes.
resource "tls_private_key" "control_to_workers" {
  algorithm = "ED25519"
}

# Create Public IPs for each server
resource "azurerm_public_ip" "pip" {
  for_each            = local.public_nodes
  name                = "${each.key}-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Network Interfaces (NICs)
resource "azurerm_network_interface" "nic" {
  for_each            = local.servers
  name                = "${each.key}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.ip
    public_ip_address_id          = contains(local.public_nodes, each.key) ? azurerm_public_ip.pip[each.key].id : null
  }
}

# Attach the Security Group (NSG) to each NIC
resource "azurerm_network_interface_security_group_association" "assoc" {
  for_each                  = local.servers
  network_interface_id      = azurerm_network_interface.nic[each.key].id
  network_security_group_id = azurerm_network_security_group.frappe_nsg.id
}

# Create the Virtual Machines
resource "azurerm_linux_virtual_machine" "vm" {
  for_each              = local.servers
  name                  = each.key
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = each.value.size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  # Automatically reads your local SSH key file
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  # Add control-node public key on worker nodes only.
  dynamic "admin_ssh_key" {
    for_each = each.key == "press-control" ? [] : [1]
    content {
      username   = var.admin_username
      public_key = tls_private_key.control_to_workers.public_key_openssh
    }
  }

  # Press-control runs full bootstrap; workers keep minimal cloud-init setup.
  custom_data = each.key == "press-control" ? base64encode(templatefile("${path.module}/setup_control.sh", {
    admin_username            = var.admin_username
    root_domain               = var.root_domain
    db_root_password_shell    = replace(var.db_root_password, "'", "'\"'\"'")
    site_admin_password_shell = replace(var.site_admin_password, "'", "'\"'\"'")
    control_private_key_b64   = base64encode(tls_private_key.control_to_workers.private_key_openssh)
    })) : base64encode(<<-EOF
    #cloud-config
    users:
      - default
      - name: ${var.admin_username}
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
  EOF
  )

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}