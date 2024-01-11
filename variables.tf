variable "tfc_state_org" {
  description = "TFC Organization where to access remote_state from"
  default = "JoeStack"
}

variable "rs_platform_hcp" {
  description = "TFC Workspace where to consume outputs from (cluster_url)"
  default = "tfc-aws-hashistack"
}

# variable "aws_region" {
#   description = "AWS region"
#   default     = "eu-west-1"
# }

variable "pub_key" {
  description = "the public key to be used to access the bastion host and ansible nodes"
  default     = "joestack"
}

# variable "consul_version" {
#   description = "i.e. 1.11.2 or 1.11.2+ent nowadays +ent-1 'apt-cache show consul-enterprise'"
#   default     = "1.17.1+ent-1"
# }

variable "node_count" {
  description = "Amount of Consul Agent Client nodes"
  default = 3
}
