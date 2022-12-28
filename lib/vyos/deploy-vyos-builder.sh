#!/bin/bash 

if [ -z $1  ]; then
    echo  "Usage: $0 create|destroy" 
    exit 1
fi

function destory_vm(){
    sudo kvm-install-vm  remove vyos-builder
    sudo virsh destroy  vyos-builder
    sudo virsh undefine  vyos-builder
    sudo rm -rf /var/lib/libvirt/images/vyos-builder.qcow2
}

function deploy_vyos_builder_vm(){
    sudo  kvm-install-vm  create -t  debian10  -c 2 -m 4096 -d 60  -l /var/lib/libvirt/images/ -L /var/lib/libvirt/images/ vyos-builder
    echo "Run the following commands"
    echo "*************************"
    echo "sudo su - root "
    IPADDR=$(sudo virsh net-dhcp-leases default | grep vyos-builder | awk '{print $5}' | sed 's/\/24//g')
    echo 'ssh -i /root/.ssh/id_rsa  debian@'${IPADDR}''
    sudo virsh net-dhcp-leases default
}


if [ $1  ==  "create"  ]; then
    deploy_vyos_builder_vm
elif [ $1  ==  "destroy"  ]; then
    destory_vm
fi