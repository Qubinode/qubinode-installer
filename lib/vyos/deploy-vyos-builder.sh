#!/bin/bash 

if [  -z $1  ]; then
    echo  "Usage: $0 create|destroy bridge" 
    exit 1
fi

if [ -z $2  ]; then
    USE_BRIDGE=false
else   
    USE_BRIDGE=true
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
    DEFINED_BRIDGE=$(awk '/qubinode_bridge_name:/ {print $2; exit}' "${kvm_host_vars_file}"| tr -d '"')
fi

function destory_vm(){
    sudo kvm-install-vm  remove vyos-builder
    sudo virsh destroy  vyos-builder
    sudo virsh undefine  vyos-builder
    sudo rm -rf /var/lib/libvirt/images/vyos-builder.qcow2
}

function deploy_vyos_builder_vm(){
    if [ $USE_BRIDGE  ==  "true"  ]; then
        sudo kvm-install-vm  create -t  debian10  -c 2 -m 4096 -d 60  -l /var/lib/libvirt/images/ -L /var/lib/libvirt/images/ -b $DEFINED_BRIDGE vyos-builder
    else
        sudo kvm-install-vm  create -t  debian10  -c 2 -m 4096 -d 60  -l /var/lib/libvirt/images/ -L /var/lib/libvirt/images/ vyos-builder
    fi

    echo "waiting 60 seconds  for VM to get IP address"
    sleep 60s
    echo "Run the following commands"
    echo "*************************"
    echo "sudo su - root "
    if [ $USE_BRIDGE  ==  "false"  ]; then
        IPADDR=$(sudo virsh net-dhcp-leases default | grep vyos-builder | awk '{print $5}' | sed 's/\/24//g')
    else
        MAC_ADDRESS=$( sudo  virsh domiflist vyos-builder | grep bridge | awk '{print $5}')
        IPADDR=$(nmap -sP 192.168.1.0/24 | grep  -B2  ${MAC_ADDRESS} | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    fi

    echo 'ssh -i /root/.ssh/id_rsa  debian@'${IPADDR}''
    #sudo virsh net-dhcp-leases default
}

function qubinode_vyos_router_builder(){
    if [ $1  ==  "create"  ]; then
        deploy_vyos_builder_vm
    elif [ $1  ==  "destroy"  ]; then
        destory_vm
    fi
}
