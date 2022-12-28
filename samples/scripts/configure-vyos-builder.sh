#!/bin/bash

if [ -z $1  ]; then
    echo  "Usage: $0 create|destroy" 
    exit 1
fi

if [ ! -f /root/vyos-env ];
then 
    echo "vyos-env file not found.  Please create it and try again."
    exit 
else 
    source /root/vyos-env
fi 

if [ ! -f /usr/bin/ansible ];
then
    sudo apt update
    sudo apt install -y ansible python curl git apache2 ufw
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo systemctl status apache2
fi

if [ ! -f /tmp/vyos-rolling-latest.iso ]; then
    cd /tmp/
    curl -OL https://s3-us.vyos.io/rolling/current/vyos-rolling-latest.iso
    cd $HOME
fi

if [ ! -d $HOME/vyos-vm-images ]; then
    git clone https://github.com/vyos/vyos-vm-images.git
fi


function create(){
  cd $HOME/vyos-vm-images


  cat >user-data<<EOF
#cloud-config
vyos_config_commands:
  - set system host-name '${ROUTER_NAME}'
  - set system ntp server ${TIME_SERVER_1}
  - set system ntp server ${TIME_SERVER_2}
  - set interfaces ethernet eth0 address '${MAIN_ROUTER_IP}'
  - set interfaces ethernet eth0 description 'INTERNET_FACING'
  - set interfaces ethernet eth1 address ${ETH1_IP_OCTECT}.1/24
  - set interfaces ethernet eth1 description ${ETH1_NAME}
  - set interfaces ethernet eth1 vif ${VLAN_ID} description 'VLAN ${VLAN_ID}'
  - set interfaces ethernet eth1 vif ${VLAN_ID} address '${ETH1_VLAN_OCTECT}.1/24'
  - set interfaces ethernet eth2 address ${ETH2_IP_OCTECT}.1/24
  - set interfaces ethernet eth2 description ${ETH2_NAME} 
  - set nat source rule 10 outbound-interface 'eth0'
  - set nat source rule 10 source address ${ETH1_IP_OCTECT}.0/24
  - set nat source rule 10 translation address masquerade
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 default-router '${ETH1_IP_OCTECT}.1'
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 domain-name '${FQN}'
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24  name-server '${DNS_SERVER}'
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 lease '86400'
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 range 0 start ${ETH1_IP_OCTECT}.20
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 range 0 stop '${ETH1_IP_OCTECT}.100'
EOF

  cat >meta-data<<EOF
EOF

cat >network-config<<EOF
version: 2
ethernets:
  eth0:
    dhcp4: false
    dhcp6: false
EOF

  genisoimage  -output seed.iso -volid cidata -joliet -rock user-data meta-data network-config

  ansible-playbook qemu.yml -e iso_local=/tmp/vyos-rolling-latest.iso  -e grub_console=serial  -e guest_agent=qemu -e keep_user=true -e enable_dhcp=false -e enable_ssh=true  -e cloud_init=true -e cloud_init_ds=NoCloud
  QCOW_IMAGE_NAME=$(basename /tmp/vyos-*.qcow2 | sed 's/ //g')
  sudo mv /tmp/vyos-*.qcow2 /var/www/html/
  sudo mv $HOME/vyos-vm-images/seed.iso /var/www/html/
  sudo chmod -R 755 /var/www/html/
  echo "Run the command below on host server to create the router"
  echo "cd qubinode-installer"
  echo "lib/vyos/deploy-vyos-router.sh create $(basename /tmp/vyos-*.qcow2 | sed 's/ //g')"
}


function destroy(){
  rm -rf /tmp/vyos-*.qcow2
  sudo rm -rf /var/www/html/*.qcow2
  sudo rm -rf /var/www/html/seed.iso
}



if [ $1 == "create" ]; then
    create
elif [ $1 == "destroy" ]; then
    destroy
else
    echo "Usage: $0 create|destroy"
fi