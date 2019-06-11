# -*- mode: ruby -*-
# vi: set ft=ruby :
#Vagrant::DEFAULT_SERVER_URL.replace('https://vagrantcloud.com')
# Require YAML module
require 'yaml'

config = YAML.load_file(File.join(File.dirname(__FILE__), 'vagrant_config.yml'))

base_flavour=config['environment']['base_flavour']

base_box=config['environment']['base_box']

base_box_version=config['environment']['base_box_version']

domain=config['environment']['domain']

boxes = config['boxes']

boxes_hostsfile_entries=""

boxes_hosts=""

 boxes.each do |box|
   boxes_hostsfile_entries=boxes_hostsfile_entries+box['mgmt_ip'] + ' ' +  box['name'] + ' ' + box['name']+'.'+domain+'\n'
   boxes_hosts=boxes_hosts+box['mgmt_ip'] + ' '
  end

docker_engine_version=config['environment']['docker_engine_version']
kubernetes_version=config['environment']['kubernetes_version']
kubernetes_token=config['environment']['kubernetes_token']
etcd_nodes=config['environment']['etcd_nodes']
etcd_nodes_count=etcd_nodes.length


def array_values_to_array_of_hashes(l)
	result = l
	if l.is_a?(Array) and l.length > 0
		if not l[0].is_a?(Hash)	# check the first value
			result = l.each_with_object([]) { |x, a| a.push({:name => x}) }
		end
	end
	return result
end


update_hosts = <<SCRIPT
    echo "127.0.0.1 localhost" >/etc/hosts
    echo -e "#{boxes_hostsfile_entries}" |tee -a /etc/hosts
SCRIPT

deb_ansible_enablement = <<SCRIPT
  DEBIAN_FRONTEND=noninteractive apt-get install -qq python
  useradd -m -s /bin/bash provision
  mkdir -p ~provision/.ssh
  cp /vagrant/keys/*provision.pub ~provision/.ssh/authorized_keys
  chown -R provision:provision ~provision/.ssh
  chmod -R 700 ~provision/.ssh
  echo "provision ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/provision
  echo "Defaults:provision !requiretty" >>/etc/sudoers.d/provision
SCRIPT

deb_install_common_software  = <<SCRIPT
  systemctl stop apt-daily.timer
  systemctl disable apt-daily.timer
  sed -i '/Update-Package-Lists/ s/1/0/' /etc/apt/apt.conf.d/10periodic
  sudo killall apt apt-get
  while true;do fuser -vki /var/lib/apt/lists/lock || break ;done
  apt-get update -qq \
  && apt-get install -qq \
  ntpdate \
  ntp \
  python \
  && timedatectl set-timezone Europe/Madrid
SCRIPT

rh_ansible_enablement = <<SCRIPT
  yum install -y -q -e 0 python
  useradd -m -s /bin/bash provision
  mkdir -p ~provision/.ssh
  cp /vagrant/keys/*provision.pub ~provision/.ssh/authorized_keys
  chown -R provision:provision ~provision/.ssh
  chmod -R 700 ~provision/.ssh
  echo "provision ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/provision
  echo "Defaults:provision !requiretty" >>/etc/sudoers.d/provision
SCRIPT

rh_install_common_software  = <<SCRIPT
  systemctl stop packagekit
  systemctl mask packagekit
  yum install -y -q -e 0 \
  ntpdate \
  ntp \
  python \
  && timedatectl set-timezone Europe/Madrid
SCRIPT

deb_install_kubernetes = <<SCRIPT
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list 
  apt-get update -qq
  apt-get install -y --allow-unauthenticated kubelet=$1 kubeadm=$1 kubectl=$1 kubernetes-cni
  sed -i \'9s/^/Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false"\\n/\' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  systemctl daemon-reload
  systemctl enable kubelet
  echo "Kubelet Configured without Swap"
SCRIPT

deb_install_docker_engine = <<SCRIPT
  DEBIAN_FRONTEND=noninteractive apt-get remove -qq docker docker-engine docker.io
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -qq \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  bridge-utils
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | DEBIAN_FRONTEND=noninteractive apt-key add -
  add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"
  DEBIAN_FRONTEND=noninteractive apt-get -qq update
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce=$1
  usermod -aG docker vagrant >/dev/null
SCRIPT

deb_install_etcd = <<SCRIPT
  DEBIAN_FRONTEND=noninteractive apt-get install -qq \
  etcd
  curl -s -o /usr/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 
  curl -s -o /usr/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
  chmod +x /usr/bin/cfssl*
SCRIPT

deb_disable_autoupdates = <<SCRIPT
    echo 'APT::Periodic::Enable \"0\";' > /etc/apt/apt.conf.d/02periodic
    systemctl disable apt-daily.service
    systemctl disable apt-daily.timer
SCRIPT

deb_configure_etcd = <<SCRIPT
  mkdir -p /etc/kubernetes/pki/etcd  
  cp /vagrant/etcd/* /etc/kubernetes/pki/etcd
  mkdir -p /vagrant/tmp/etcd
  cp /vagrant/etcd/* /vagrant/tmp/etcd
  cd /vagrant/tmp/etcd
  [ ! -f ca.pem -o ! -f ca-key.pem -o ! -f ca.csr ] && export FIRSTNODE=$1 && cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
  [ ! -f client.pem -o ! -f client-key.pem -o ! -f client.csr ] && cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client.json | cfssljson -bare client
  cfssl print-defaults csr > config.json
  sed -i 's/www\.example\.net/'"$2"'/' config.json
  sed -i 's/example\.net/'"$1"'/' config.json
  sed -i '0,/CN/{s/example\.net/'"$1"'/}' config.json
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server config.json | cfssljson -bare server
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer config.json | cfssljson -bare peer

  cp /vagrant/tmp/etcd/* /etc/kubernetes/pki/etcd


  echo "PEER_NAME=$1" >> /etc/etcd.env
  echo "PRIVATE_IP=$2" >> /etc/etcd.env
  mv /etc/kubernetes/pki/etcd/etcd.service /etc/systemd/system/etcd.service
  sed -i 's/__NODE_NAME__\/'"$1"'/' /etc/systemd/system/etcd.service 
  sed -i 's/__NODE_IP__\/'"$2"'/' /etc/systemd/system/etcd.service
  
  CLUSTER_STATE="new"
  i=1
  while [ $i -le $3 ]
  do
    [ ! -f /vagrant/tmp/master$i ] && printf "${1}=http:\\/\\/${2}:2380" >> /vagrant/tmp/master$i && break
    CLUSTER_STATE="existing"
    i=$((i + 1 ))
  done

  for file in /vagrant/tmp/master*
  do
    MASTERS="${MASTERS},$(cat $file)"
  done
  
  MASTERS="$(echo $MASTERS|sed -e "s/^,//")"
  
  sed -i 's/__MASTERS__/'"${MASTERS}"'/' /etc/systemd/system/etcd.service

  sed -i 's/__CLUSTER_STATE__/'"${CLUSTER_STATE}"'/' /etc/systemd/system/etcd.service

  systemctl daemon-reload
  systemctl enable etcd
  systemctl stop etcd
  rm -rf /var/lib/etcd/*
  systemctl start etcd
  etcdctl cluster-health
  echo ${FIRSTNODE}

SCRIPT


deb_install_nginx = <<SCRIPT
  DEBIAN_FRONTEND=noninteractive apt-get install -qq \
  nginx
SCRIPT

deb_configure_nginx = <<SCRIPT
  echo "Do nothing ..."
SCRIPT
Vagrant.configure(2) do |config|
  VAGRANT_COMMAND = ARGV[0]
#   if VAGRANT_COMMAND == "ssh"
#    config.ssh.username = 'ubuntu'
#    config.ssh.password = 'ubuntu'
#   end
  config.vm.box = base_box
  config.vm.box_version = base_box_version

#  config.vm.synced_folder "tmp_deploying_stage/", "/tmp_deploying_stage",create:true
#  config.vm.synced_folder "src/", "/src",create:true
  boxes.each do |node|
    config.vm.define node['name'] do |config|
      config.vm.hostname = node['name']
      config.vm.provider "virtualbox" do |v|
	      v.linked_clone = true
        config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"       
	      v.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
        v.name = node['name']
        v.customize ["modifyvm", :id, "--memory", node['mem']]
        v.customize ["modifyvm", :id, "--cpus", node['cpu']]

        v.customize ["modifyvm", :id, "--nictype1", "Am79C973"]
        v.customize ["modifyvm", :id, "--nictype2", "Am79C973"]
        v.customize ["modifyvm", :id, "--nictype3", "Am79C973"]
        v.customize ["modifyvm", :id, "--nictype4", "Am79C973"]
        v.customize ["modifyvm", :id, "--nicpromisc1", "allow-all"]
        v.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
        v.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
        v.customize ["modifyvm", :id, "--nicpromisc4", "allow-all"]
        v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      end

      config.vm.network "private_network",
      ip: node['mgmt_ip'],:netmask => "255.255.255.0",
      virtualbox__intnet: false,
      hostonlyadapter: ["vboxnet1"]

      config.vm.network "private_network",
      ip: node['data_ip'],:netmask => "255.255.255.0",
      virtualbox__intnet: false,
      hostonlyadapter: ["vboxnet2"]

      config.vm.network "public_network",
      bridge: ["enp4s0","wlp3s0","enp3s0f1","wlp2s0","enp3s0"],
      auto_config: true

      #config.vm.provision "disable-apt-periodic-updates", type: "shell" do |s|
    	#s.privileged = true
    	#s.inline = "echo 'APT::Periodic::Enable \"0\";' > /etc/apt/apt.conf.d/02periodic"
      #end

      config.vm.provision :shell, :inline => update_hosts

      if base_flavour.downcase == "redhat"
        config.vm.provision :shell, :inline => rhn_disable_autoupdatess
      else
        config.vm.provision :shell, :inline => deb_disable_autoupdates
      end


      if base_flavour.downcase == "redhat"
        config.vm.provision :shell, :inline => rh_install_common_software
        config.vm.provision :shell, :inline => rh_ansible_enablement
      else
        config.vm.provision :shell, :inline => deb_install_common_software
        config.vm.provision :shell, :inline => deb_ansible_enablement           
      end

      if node['role'] == "manager"
        if base_flavour.downcase == "redhat"
          config.vm.provision :shell, :inline => rh_install_kubernetes
        else
          config.vm.provision :shell, :inline => deb_install_docker_engine, :args => docker_engine_version
          config.vm.provision :shell, :inline => deb_install_kubernetes, :args => kubernetes_version      
          config.vm.provision :shell, :inline => deb_install_etcd       
        end
        #config.vm.provision :shell, :inline => deb_configure_etcd, :args => [node['name'], node['mgmt_ip'],etcd_nodes_count]

      end
      
      if node['role'] == "loadbalancer"
        if base_flavour.downcase == "redhat"
          config.vm.provision :shell, :inline => rh_install_nginx
        else
          config.vm.provision :shell, :inline => deb_install_nginx 
        end
        #config.vm.provision :shell, :inline => deb_configure_nginx, :args => [node['name'], node['mgmt_ip'],etcd_nodes_count]

      end           
    end

  end


end
