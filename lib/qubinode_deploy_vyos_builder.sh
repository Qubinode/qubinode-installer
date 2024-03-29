#!/bin/bash 


function vyos_variables () {
    setup_variables
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
    SUBNET=$(cat "${kvm_host_vars_file}" | grep kvm_subnet: | awk '{print $2}')
    USE_BRIDGE=$(cat "${kvm_host_vars_file}" | grep use_vyos_bridge: | awk '{print $2}')
}


function destory_vm(){
    sudo kvm-install-vm  remove vyos-builder
    sudo virsh destroy  vyos-builder
    sudo virsh undefine  vyos-builder
    sudo rm -rf /var/lib/libvirt/images/vyos-builder.qcow2
}

function deploy_vyos_builder_vm(){
    if [ $USE_BRIDGE  ==  "true"  ]; then
        kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
        DEFINED_BRIDGE=$(awk '/qubinode_bridge_name:/ {print $2; exit}' "${kvm_host_vars_file}"| tr -d '"')
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
        IPADDR=$(sudo virsh net-dhcp-leases default | grep vyos-builder  | sort -k1 -k2 | tail -1 | awk '{print $5}' | sed 's/\/24//g')
    else
        MAC_ADDRESS=$( sudo  virsh domiflist vyos-builder | grep bridge | awk '{print $5}')
        IPADDR=$(sudo nmap -sP ${SUBNET} | grep  -B2  ${MAC_ADDRESS^^} | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    fi

    echo 'ssh -i /root/.ssh/id_rsa  debian@'${IPADDR}''
    #sudo virsh net-dhcp-leases default
}

function qubinode_vyos_router_maintenance(){
    echo "Run the following commands"
    case ${product_maintenance} in
       create)
           vyos_variables
           deploy_vyos_builder_vm
           ;;
       destroy)
           destory_vm
           ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}
