output "web_clients" {
  value       = aws_instance.consul_client_web[*].public_ip
  description = "EC2 public IP"
}

output "db_clients" {
  value       = aws_instance.consul_client_db[*].public_ip
  description = "EC2 public IP"
}

output "consul_token" {
  value = local.consul_init_token
}

output "tls_self_signed_cert" {
  value = local.consul_ca_file
}

output "consul_cluster_addr" {
  value = "https://${local.consul_cluster_addr}:8501"
}

output "vault_cluster_url" {
  value = "https://${local.consul_cluster_addr}:8200"
}

output "vault_root_token" {
  value = local.vault_root_token
}

# output "consul_agent_token" {
#   value = data.vault_generic_secret.consul_agent_token.data["token"]
#   sensitive = true
# }