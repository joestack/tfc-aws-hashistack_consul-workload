#!/bin/bash

install_deps() {
  curl -sL 'https://deb.dl.getenvoy.io/public/gpg.8115BA8E629CC074.key' | gpg --dearmor -o /usr/share/keyrings/getenvoy-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/getenvoy-keyring.gpg] https://deb.dl.getenvoy.io/public/deb/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/getenvoy.list
  apt update -qy
  version="${consul_version}"
  consul_package="consul-enterprise="$${version:1}"*"
  apt install -qy apt-transport-https gnupg2 curl lsb-release nomad ${consul_apt}=${consul_version} getenvoy-envoy unzip jq apache2-utils nginx

  curl -fsSL https://get.docker.com -o get-docker.sh
  sh ./get-docker.sh
}

setup_networking() {
  # echo 1 | tee /proc/sys/net/bridge/bridge-nf-call-arptables
  # echo 1 | tee /proc/sys/net/bridge/bridge-nf-call-ip6tables
  # echo 1 | tee /proc/sys/net/bridge/bridge-nf-call-iptables
  curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v1.0.0/cni-plugins-linux-$([ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v1.0.0.tgz
  mkdir -p /opt/cni/bin
  tar -C /opt/cni/bin -xzf cni-plugins.tgz
}

setup_consul() {
  mkdir --parents /etc/consul.d /var/consul
  chown --recursive consul:consul /etc/consul.d
  chown --recursive consul:consul /var/consul

  echo "${consul_ca}" | base64 -d >/etc/consul.d/ca.pem

  tee /etc/consul.d/client.hcl > /dev/null <<EOF
  data_dir         = "/opt/consul/"
  log_level        = "INFO"
  server           = false
  datacenter       = "${datacenter}"
  bind_addr        = "{{ GetPrivateInterfaces | include \"network\" \"${vpc_cidr}\" | attr \"address\" }}"
  retry_join       = ["${consul_cluster}"]

  ui_config = {
  enabled = true
  }

  encrypt = "${consul_gossip_key}"
  
  auto_encrypt = {
    tls = true
  } 

  tls {
  defaults {
    ca_file = "/etc/consul.d/ca.pem"
    verify_incoming = true
    }
  }

  ports = {
    grpc = 8502
  }
EOF

tee /etc/systemd/system/consul.service > /dev/null <<EOF
[Unit]
Description="${service_name}"
Requires=network-online.target
After=network-online.target

[Service]
Environment="PORT=80"
Type=simple
WorkingDirectory=/etc/consul.d/
ExecStart=${service_cmd}
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF



}

consul_service() {
tee /etc/consul.d/${consul_svc_name}-svc.hcl > /dev/null <<EOF
service {
  name = "${consul_svc_name}"
  id   = "${consul_svc_id}"
  port = 80
  tags = ["primary"]
}
EOF

chown --recursive consul:consul /etc/consul.d
}

start_service() {
  systemctl enable $1.service
  systemctl start $1.service
}



cd /home/ubuntu/

setup_networking
install_deps

setup_consul
#consul_service

start_service "consul"

# nomad and consul service is type simple and might not be up and running just yet.
sleep 10

echo "done"
