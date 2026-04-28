variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  default     = "myfrappe-cloud-rg"
}

variable "location" {
  description = "Azure Region"
  default     = "centralindia"
}

variable "admin_username" {
  description = "Admin username for all VMs"
  default     = "frappeadmin"
}

variable "ssh_public_key_path" {
  description = "The local path to your SSH public key file"
  type        = string
  default     = "C:/Users/SagarMemane/.ssh/id_ed25519.pub"
}

variable "root_domain" {
  description = "The root domain for your cloud"
  default     = "cogniticon.in"
}

variable "db_root_password" {
  description = "MariaDB root password used during control node bootstrap"
  type        = string
  sensitive   = true
}

variable "site_admin_password" {
  description = "Frappe site admin password used for dashboard site creation"
  type        = string
  sensitive   = true
}