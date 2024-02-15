# Basic usage

provider "vault" {
  address = "https://${local.consul_cluster_addr}:8200"
  skip_tls_verify = true
  auth_login {
    path = "auth/userpass/login/${local.vault_user}"

    parameters = {
      password = local.vault_user_pw
    }
  }
}

data "vault_generic_secret" "consul_agent_token" {
  path = "consul-services/creds/services-role"
}


provider "consul" {
  address    = "${local.consul_cluster_addr}:8500"
  datacenter = local.consul_datacenter
  token      = local.consul_init_token
}

