data "terraform_remote_state" "hcp" {
  backend = "remote"

  config = {
    organization = var.tfc_state_org
    workspaces = {
      name = var.rs_platform_hcp
    }
  }
}

data "terraform_remote_state" "l2" {
  backend = "remote"

  config = {
    organization = var.tfc_state_org
    workspaces = {
      name = var.rs_platform_l2
    }
  }
}

provider "aws" {
  region = local.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

locals {
  consul_cluster_addr    = data.terraform_remote_state.hcp.outputs.cluster_url
  consul_datacenter      = data.terraform_remote_state.hcp.outputs.consul_datacenter
  consul_init_token      = data.terraform_remote_state.hcp.outputs.consul_init_token
  #consul_agent_token     = data.vault_generic_secret.consul_agent_token.data["token"]
  #consul_services_token  = random_uuid.services.id
  consul_gossip_key      = data.terraform_remote_state.hcp.outputs.consul_gossip_key
  consul_apt             = length(split("+", local.consul_version)) == 2 ? "consul-enterprise" : "consul"
  consul_ca_file         = data.terraform_remote_state.hcp.outputs.consul_ca_file
  consul_version         = data.terraform_remote_state.hcp.outputs.consul_version
  aws_region             = data.terraform_remote_state.hcp.outputs.aws_region
  vpc_id                 = data.terraform_remote_state.hcp.outputs.vpc_id
  vpc_cidr               = data.terraform_remote_state.hcp.outputs.vpc_cidr
  consul_vpc_security_id = data.terraform_remote_state.hcp.outputs.consul_vpc_security_id
  hashistack_subnet      = data.terraform_remote_state.hcp.outputs.hashistack_subnet
  vault_user             = data.terraform_remote_state.l2.outputs.vault_user
  vault_user_pw          = data.terraform_remote_state.l2.outputs.vault_user_pw
  vault_agent_token      = data.terraform_remote_state.l2.outputs.vault_agent_token
  tls_self_signed_cert   = data.terraform_remote_state.hcp.outputs.tls_self_signed_cert
}


data "template_file" "client" {
  count = var.node_count
  template = (join("\n", tolist([
    file("${path.root}/scripts/base.sh"),
    file("${path.root}/scripts/client.sh")
  ])))
  vars = {
      tls_self_signed_cert = local.tls_self_signed_cert
      consul_ca         = local.consul_ca_file
      datacenter        = local.consul_datacenter
      consul_cluster    = local.consul_cluster_addr
      consul_vpc_security_id = local.consul_vpc_security_id
      consul_gossip_key = local.consul_gossip_key
      vpc_cidr          = local.vpc_cidr
      consul_acl_token  = local.consul_init_token
      #consul_agent_token = local.consul_agent_token
      vault_agent_token = local.vault_agent_token
      consul_version    = local.consul_version
      consul_apt        = local.consul_apt
      consul_svc_name   = "webservice"
      consul_svc_id     = "webservice-${count.index + 1}"
      service_name      = "consul",
      service_cmd       = "/usr/bin/consul agent -data-dir /var/consul -config-dir=/etc/consul.d/",
      }
}

data "template_cloudinit_config" "client" {
  count         = var.node_count
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content      = element(data.template_file.client.*.rendered, count.index)
  }
}




# 
// Consul client instance
resource "aws_instance" "consul_client_web" {
  count                       = var.node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.small"
  associate_public_ip_address = true
  subnet_id                   = element(local.hashistack_subnet, count.index)
  vpc_security_group_ids    = [ local.consul_vpc_security_id ]
  key_name                  = var.pub_key
  user_data = element(data.template_cloudinit_config.client.*.rendered, count.index)


  tags = {
    Name = "webservice-${count.index}"
  }
}








data "template_file" "db-client" {
  count = var.node_count
  template = (join("\n", tolist([
    file("${path.root}/scripts/base.sh"),
    file("${path.root}/scripts/client.sh")
  ])))
  vars = {
      tls_self_signed_cert = local.tls_self_signed_cert
      consul_ca         = local.consul_ca_file
      datacenter        = local.consul_datacenter
      consul_cluster    = local.consul_cluster_addr
      consul_vpc_security_id = local.consul_vpc_security_id
      consul_gossip_key = local.consul_gossip_key
      vpc_cidr          = local.vpc_cidr
      consul_acl_token  = local.consul_init_token
      #consul_agent_token = local.consul_agent_token
      vault_agent_token = local.vault_agent_token
      consul_version    = local.consul_version
      consul_apt        = local.consul_apt
      consul_svc_name   = "dbservice"
      consul_svc_id     = "dbservice-${count.index + 1}"
      service_name      = "consul",
      service_cmd       = "/usr/bin/consul agent -data-dir /var/consul -config-dir=/etc/consul.d/",
      }
}

data "template_cloudinit_config" "db-client" {
  count         = var.node_count
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content      = element(data.template_file.db-client.*.rendered, count.index)
  }
}




# 
// Consul client instance
resource "aws_instance" "consul_client_db" {
  count                       = var.node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.small"
  associate_public_ip_address = true
  subnet_id                   = element(local.hashistack_subnet, count.index)
  vpc_security_group_ids    = [ local.consul_vpc_security_id ]
  key_name                  = var.pub_key
  user_data = element(data.template_cloudinit_config.db-client.*.rendered, count.index)


  tags = {
    Name = "dbservice-${count.index}"
  }
}





# resource "aws_instance" "consul_client_db" {
#   count                       = 3
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = "t2.small"
#   associate_public_ip_address = true
#   subnet_id                   = element(local.hashistack_subnet, count.index)
# #   vpc_security_group_ids = [
# #     aws_security_group.allow_ssh.id,
# #     aws_security_group.my_asg.id
# #   ]
#   #key_name = aws_key_pair.consul_client.key_name
#   key_name = var.pub_key

#   user_data = templatefile("${path.module}/scripts/user_data.sh", {
#     setup = base64gzip(templatefile("${path.module}/scripts/setup.sh", {
#       consul_ca        = local.consul_ca_file
#       #consul_config    = local.client_config_file
#       datacenter       = local.consul_datacenter
#       consul_cluster   = local.consul_cluster_addr
#       consul_gossip_key = local.consul_gossip_key
#       vpc_cidr         = local.vpc_cidr
#       consul_acl_token = local.consul_init_token
#       consul_version   = var.consul_version
#       consul_apt       = local.consul_apt
#       consul_svc_name  = "dbservice"
#       consul_svc_id    = "dbservice-${count.index + 1}"
#       consul_service   = base64encode(templatefile("${path.module}/scripts/service", {
#         service_name   = "consul",
#         service_cmd    = "/usr/bin/consul agent -data-dir /var/consul -config-dir=/etc/consul.d/",
#       })),
#       vpc_cidr = local.vpc_cidr
#     })),
#   })

#   tags = {
#     Name = "dbservice-${count.index}"
#   }
# }









