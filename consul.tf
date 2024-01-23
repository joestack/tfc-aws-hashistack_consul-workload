# Basic usage

provider "consul" {
  address    = local.consul_cluster_addr
  datacenter = local.consul_datacenter
  token      = local.consul_init_token
}



resource "consul_acl_policy" "services" {
  name  = "services"
  rules = <<-RULE
    service_prefix "" {
	  policy = "write"
	  intentions = "write"
    }
    RULE
}

resource "consul_acl_token" "services" {
  description = "services token"
  policies    = [consul_acl_policy.services.name]
  local       = true
}

# Explicitly set the `accessor_id`

resource "random_uuid" "services" {}

resource "consul_acl_token" "test_predefined_id" {
  accessor_id = random_uuid.services.result
  description = "my test uuid token"
  policies    = [consul_acl_policy.services.name]
  local       = true
}