# Generate a unique SSH key pair for the cluster
resource "tls_private_key" "internal_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# (Optional) Save the private key to your local laptop just in case
resource "local_file" "private_key" {
  content         = tls_private_key.internal_ssh_key.private_key_pem
  filename        = "${path.module}/cluster_internal_key.pem"
  file_permission = "0600"
}