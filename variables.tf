variable "remote_state_org" {
  description = "Terraform Organization where to access remote_state from"
  default = "JoeStack"
}

variable "remote_state_l1" {
  description = "TFC Workspace where to consume outputs from (cluster_url)"
  default = "hashistack-l1-platform"
}

variable "remote_state_l2" {
  description = "TFC Worspace to retrive 2nd Layer infromation from"
  default     = "hashistack-l2-services"
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
