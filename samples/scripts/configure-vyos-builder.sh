#!/bin/bash
#set -x 
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
    sudo apt install -y ansible python curl git apache2 ufw unzip

    if [ ${TAREGT_ENV} == "vmware" ]; then
        sudo apt -y  install build-essential gcc libssl-dev
    fi

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

    if [ ${TAREGT_ENV} == "vmware" ]; then
      wget http://192.168.1.240/VMware-ovftool-4.4.3-18663434-lin.x86_64.zip
      unzip VMware-ovftool-4.4.3-18663434-lin.x86_64.zip
      ln -s /root/ovftool/ovftool  /usr/local/bin/
      
      if [ ! -d $HOME/open-vmdk ]; then
        git clone https://github.com/vmware/open-vmdk.git
        cd open-vmdk/
        make 
        make install 
      fi

      generate_cert
    fi
fi

if [ ! -f /usr/local/bin/ovftool ];
then
    if [ ${TAREGT_ENV} == "vmware" ]; then
      wget http://192.168.1.240/VMware-ovftool-4.4.3-18663434-lin.x86_64.zip
      unzip VMware-ovftool-4.4.3-18663434-lin.x86_64.zip
      ln -s /root/ovftool/ovftool  /usr/local/bin/
      
      if [ ! -d $HOME/open-vmdk ]; then
        git clone https://github.com/vmware/open-vmdk.git
        cd open-vmdk/
        make 
        make install 
      fi

      generate_cert
    fi
fi 


function create(){
  cd $HOME/vyos-vm-images

  if [ ${TAREGT_ENV} == "kvm" ]; then
    cat >user-data<<EOF
#cloud-config
vyos_config_commands:
  - set system host-name '${ROUTER_NAME}'
  - set system ntp server ${TIME_SERVER_1}
  - set system ntp server ${TIME_SERVER_2}
  - delete interfaces ethernet eth0 address 'dhcp'
  - set interfaces ethernet eth0 address '${MAIN_ROUTER_IP}'
  - set interfaces ethernet eth0 description 'INTERNET_FACING'
  - set interfaces ethernet eth1 address '${ETH1_IP_OCTECT}.1/24'
  - set interfaces ethernet eth1 description '${ETH1_NAME}'
  - set interfaces ethernet eth1 vif ${VLAN_ID} description 'VLAN ${VLAN_ID}'
  - set interfaces ethernet eth1 vif ${VLAN_ID} address '${ETH1_VLAN_OCTECT}.1/24'
  - set interfaces ethernet eth2 address '${ETH2_IP_OCTECT}.1/24'
  - set interfaces ethernet eth2 description '${ETH2_NAME}'
  - set nat source rule 10 outbound-interface 'eth0'
  - set nat source rule 10 source address '${ETH1_IP_OCTECT}.0/24'
  - set nat source rule 10 translation address masquerade
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 default-router '${ETH1_IP_OCTECT}.1'
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 domain-name '${FQN}'
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24  name-server '${DNS_SERVER}'
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 lease '86400'
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 range 0 start '${ETH1_IP_OCTECT}.20'
  - set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 range 0 stop '${ETH1_IP_OCTECT}.100'
  - commit 
  - save 
EOF

  cat user-data

    cat >meta-data<<EOF
EOF

cat >network-config<<EOF
version: 2
ethernets:
  eth0:
    dhcp4: false
    dhcp6: false
EOF

  sleep 5s 
  genisoimage  -output seed.iso -volid cidata -joliet -rock user-data meta-data network-config

  elif [ ${TAREGT_ENV} == "vmware" ]; then
    cat >vsphere-${ROUTER_NAME}.sh<<EOF
#!/bin/vbash
#https://docs.vyos.io/en/latest/automation/command-scripting.html
# https://sivasankar.org/2018/2066/vyos-virtual-router-for-home-lab-or-smb/?utm_source=pocket_mylist
source /opt/vyatta/etc/functions/script-template
set system host-name '${ROUTER_NAME}'
set system ntp server ${TIME_SERVER_1}
set system ntp server ${TIME_SERVER_2}
delete interfaces ethernet eth0 address 'dhcp'
set interfaces ethernet eth0 address '${MAIN_ROUTER_IP}'
set interfaces ethernet eth0 description 'INTERNET_FACING'
set interfaces ethernet eth1 address '${ETH1_IP_OCTECT}.1/24'
set interfaces ethernet eth1 description '${ETH1_NAME}'
set interfaces ethernet eth1 vif ${VLAN_ID} description 'VLAN ${VLAN_ID}'
set interfaces ethernet eth1 vif ${VLAN_ID} address '${ETH1_VLAN_OCTECT}.1/24'
set interfaces ethernet eth2 address '${ETH2_IP_OCTECT}.1/24'
set interfaces ethernet eth2 description '${ETH2_NAME}'
set nat source rule 10 outbound-interface 'eth0'
set nat source rule 10 source address '${ETH1_IP_OCTECT}.0/24'
set nat source rule 10 translation address masquerade
set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 default-router '${ETH1_IP_OCTECT}.1'
set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 domain-name '${FQN}'
set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24  name-server '${DNS_SERVER}'
set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 lease '86400'
set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 range 0 start '${ETH1_IP_OCTECT}.20'
set service dhcp-server shared-network-name ${ETH1_NAME} subnet ${ETH1_IP_OCTECT}.0/24 range 0 stop '${ETH1_IP_OCTECT}.100'
commit 
save
run show interfaces
exit
EOF

    chmod +x vsphere-${ROUTER_NAME}.sh
    cat vsphere-${ROUTER_NAME}.sh
    sleep 5s 
  fi 

  if [ ${TAREGT_ENV} == "kvm" ]; then
    ansible-playbook qemu.yml -e iso_local=/tmp/vyos-rolling-latest.iso  -e grub_console=serial  -e guest_agent=qemu -e keep_user=true -e enable_dhcp=false -e enable_ssh=true  -e cloud_init=true -e cloud_init_ds=NoCloud
    QCOW_IMAGE_NAME=$(basename /tmp/vyos-*.qcow2 | sed 's/ //g')
    sudo mv /tmp/${QCOW_IMAGE_NAME} /var/www/html/${ROUTER_NAME}.qcow2
    sudo mv $HOME/vyos-vm-images/seed.iso /var/www/html/
    sudo chmod -R 755 /var/www/html/
    echo "Run the command below on host server to create the router"
    echo "cd qubinode-installer"
    echo " ./qubinode-installer -p  deploy_vyos_router -m create $(basename /var/www/html/${ROUTER_NAME}.qcow2 | sed 's/ //g')"
  elif [ ${TAREGT_ENV} == "vmware" ]; then
    generate_cert
    ansible-playbook vmware.yml -e keep_user=true -e enable_dhcp=true -e vyos_vmware_private_key_path=/root/myself.pem -e cloud_init=true -e cloud_init_ds=ConfigDrive -e guest_agent=vmware -e cloud_init_disable_config=true   -e enable_ssh=true -vvv 
    QCOW_IMAGE_NAME=$(basename /tmp/vyos-*.ova | sed 's/ //g')
    sudo mv /tmp/${QCOW_IMAGE_NAME} /var/www/html/${ROUTER_NAME}.ova
    cp vsphere-${ROUTER_NAME}.sh  /var/www/html/vsphere-${ROUTER_NAME}.sh
    sudo chmod -R 755 /var/www/html/

    echo "Download the ova and deploy on vcenter"
    echo "curl -OL http://$(hostname -I | awk '{print $1}')/${ROUTER_NAME}.ova"
    echo "ssh into deployed VM and run the following commands"
    echo "curl -OL http://$(hostname -I | awk '{print $1}')/vsphere-${ROUTER_NAME}.sh "
    echo "chmod +x vsphere-${ROUTER_NAME}.sh"
    echo "bash vsphere-${ROUTER_NAME}.sh"
  fi 

}


function destroy(){
  echo "Destroying the router image congifuration"
  if [ ${TAREGT_ENV} == "kvm" ]; then
    rm -rf /tmp/vyos-*.qcow2
    sudo rm -rf /var/www/html/*.qcow2
    sudo rm -rf /var/www/html/seed.iso
  elif [ ${TAREGT_ENV} == "vmware" ]; then
    rm -rf /tmp/vyos-*.ova
    sudo rm -rf /var/www/html/*.ova
    rm /tmp/vyos_vmware_image.ovf
    rm /tmp/vyos_vmware_image.mf
    rm /tmp/vyos_vmware_image.vmdk
    rm /tmp/vyos_raw_image.img
    rm -rf /tmp/vmware-root/
  fi
}

function generate_cert(){
  if [ -f /root/myself.pem ]; then
    echo "myself.pem  already exists"
    return
  fi
  # Generate a passphrase
  openssl req -x509 -nodes -sha256 -days 365 -newkey rsa:1024 -keyout /root/myself.pem -out /root/myself.pem  -subj "/C=US/ST=NorthCarolina/L=Raleigh/O=Red Hat/OU=Marketing/CN=vyos-builder.qubinode-lab.io" -addext "subjectAltName = DNS:vyos-builder.qubinode-lab.io" -addext "certificatePolicies = 1.2.3.4"

  openssl x509 -in /root/myself.pem -text || exit 1

}

if [ $1 == "create" ]; then
    create
elif [ $1 == "destroy" ]; then
    destroy
else
    echo "Usage: $0 create|destroy"
fi