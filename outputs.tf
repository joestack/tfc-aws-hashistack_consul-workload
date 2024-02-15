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

# output "consul_agent_token" {
#   value = data.vault_generic_secret.consul_agent_token.data["token"]
#   sensitive = true
# }