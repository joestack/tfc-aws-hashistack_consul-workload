data "terraform_remote_state" "hcp" {
  backend = "remote"

  config = {
    organization = var.tfc_state_org
    workspaces = {
      name = var.rs_platform_hcp
    }
  }
}

provider "aws" {
  region = var.aws_region
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
  consul_gossip_key      = data.terraform_remote_state.hcp.outputs.consul_gossip_key
  consul_apt             = length(split("+", var.consul_version)) == 2 ? "consul-enterprise" : "consul"
  consul_ca_file         = data.terraform_remote_state.hcp.outputs.consul_ca_file
  vpc_id                 = data.terraform_remote_state.hcp.outputs.vpc_id
  vpc_cidr               = data.terraform_remote_state.hcp.outputs.vpc_cidr
  hashistack_subnet      = data.terraform_remote_state.hcp.outputs.hashistack_subnet
}

provider "consul" {
  address    = local.consul_cluster_addr
  datacenter = local.consul_datacenter
  token      = local.consul_init_token
}




data "template_file" "client" {
  count = var.node_count
  template = (join("\n", tolist([
    file("${path.root}/templates/base.sh"),
    file("${path.root}/templates/client.sh")
  ])))
  vars = {
      consul_ca         = local.consul_ca_file
      datacenter        = local.consul_datacenter
      consul_cluster    = local.consul_cluster_addr
      consul_gossip_key = local.consul_gossip_key
      vpc_cidr          = local.vpc_cidr
      consul_acl_token  = local.consul_init_token
      consul_version    = var.consul_version
      consul_apt        = local.consul_apt
      consul_svc_name   = "webservice"
      consul_svc_id     = "webservice-${count.index + 1}"
      service_name      = "consul",
      service_cmd       = "/usr/bin/consul agent -data-dir /var/consul -config-dir=/etc/consul.d/",
      }
}

data "template_cloudinit_config" "server" {
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
#   vpc_security_group_ids = []
  key_name = var.pub_key

  tags = {
    Name = "webservice-${count.index}"
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










// Security groups
# resource "aws_security_group" "allow_ssh" {
#   name        = "allow_ssh"
#   description = "Allow SSH inbound traffic"
#   #vpc_id      = data.aws_vpc.selected.id
#   vpc_id      = local.vpc_id


#   ingress {
#     description      = "SSH into instance"
#     from_port        = 22
#     to_port          = 22
#     protocol         = "tcp"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#   }

#   tags = {
#     Name = "allow_ssh"
#   }
# }

# resource "aws_security_group" "my_asg" {
#   name        = "my_asg"
#   description = "Allow my inbound traffic"
#   #vpc_id      = data.aws_vpc.selected.id
#   vpc_id      = local.vpc_id
# }

# resource "aws_security_group_rule" "egress" {
#   security_group_id = aws_security_group.my_asg.id
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   ipv6_cidr_blocks  = ["::/0"]  
# }

# resource "aws_security_group_rule" "consul-api" {
#   #count             = var.consul_enabled ? 1 : 0
#   security_group_id = aws_security_group.my_asg.id
#   type              = "ingress"
#   from_port         = 8500
#   to_port           = 8503
#   protocol          = "tcp"
#   cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = ["::/0"]  
#   #cidr_blocks       = [var.whitelist_ip]
# }

# resource "aws_security_group_rule" "consul-dns-tcp" {
#   #count             = var.consul_enabled ? 1 : 0
#   security_group_id = aws_security_group.my_asg.id
#   type              = "ingress"
#   from_port         = 8600
#   to_port           = 8600
#   protocol          = "tcp"
#   cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = ["::/0"]
# }

# resource "aws_security_group_rule" "consul-dns-udp" {
#   #count             = var.consul_enabled ? 1 : 0
#   security_group_id = aws_security_group.my_asg.id
#   type              = "ingress"
#   from_port         = 8600
#   to_port           = 8600
#   protocol          = "udp"
#   cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = ["::/0"]
# }

# resource "aws_security_group_rule" "consul-sidecar" {
#   #count             = var.consul_enabled ? 1 : 0
#   security_group_id = aws_security_group.my_asg.id
#   type              = "ingress"
#   from_port         = 21000
#   to_port           = 21255
#   protocol          = "tcp"
#   cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = ["::/0"]
# }
