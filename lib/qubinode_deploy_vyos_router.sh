#!/bin/bash

function vyos_variables () {
    setup_variables
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
    SUBNET=$(cat "${kvm_host_vars_file}" | grep kvm_subnet: | awk '{print $2}')
    USE_BRIDGE=$(cat "${kvm_host_vars_file}" | grep use_vyos_bridge: | awk '{print $2}')
}


function create_livirt_networks(){
    array=( vyos-network-1  vyos-network-2 )
    for i in "${array[@]}"
    do
        echo "$i"

        tmp=$(sudo virsh net-list | grep "$i" | awk '{ print $3}')
        if ([ "x$tmp" == "x" ] || [ "x$tmp" != "xyes" ])
        then
            echo "$i network does not exist creating it"
            # Try additional commands here...

            cat << EOF > /tmp/$i.xml
<network>
<name>$i</name>
<bridge name='virbr$(echo "${i:0-1}")' stp='on' delay='0'/>
<domain name='$i' localOnly='yes'/>
</network>
EOF

            sudo virsh net-define /tmp/$i.xml
            sudo virsh net-start $i
            sudo virsh net-autostart  $i
    else
            echo "$i network already exists"
        fi
    done
}

function create_router(){
    create_livirt_networks
    if [ $USE_BRIDGE  ==  "false"  ]; then
        IPADDR=$(sudo virsh net-dhcp-leases default | grep vyos-builder | awk '{print $5}' | sed 's/\/24//g')
    else
        MAC_ADDRESS=$( sudo  virsh domiflist vyos-builder | grep bridge | awk '{print $5}')
        IPADDR=$(sudo nmap -sP ${SUBNET} | grep  -B2  ${MAC_ADDRESS^^} | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    fi

    cd $HOME
    curl -OL http://${IPADDR}/$1
    VM_NAME=$(basename $HOME/$1  | sed 's/.qcow2//g')
    sudo mv $HOME/${VM_NAME}.qcow2 /var/lib/libvirt/images/
    curl -OL http://${IPADDR}/seed.iso
    sudo mv $HOME/seed.iso /var/lib/libvirt/images/seed.iso



sudo virt-install -n ${VM_NAME} \
   --ram 4096 \
   --vcpus 2 \
   --cdrom /var/lib/libvirt/images/seed.iso \
   --os-variant debian10 \
   --network bridge=qubibr0,model=e1000e,mac=$(date +%s | md5sum | head -c 6 | sed -e 's/\([0-9A-Fa-f]\{2\}\)/\1:/g' -e 's/\(.*\):$/\1/' | sed -e 's/^/52:54:00:/') \
   --network network=vyos-network-1,model=e1000e \
   --network network=vyos-network-2,model=e1000e \
   --graphics vnc \
   --hvm \
   --virt-type kvm \
   --disk path=/var/lib/libvirt/images/$VM_NAME.qcow2,bus=virtio \
   --import \
   --noautoconsole
}

function destroy_router(){
    VM_NAME=$(basename $HOME/$1  | sed 's/.qcow2//g')
    sudo virsh destroy ${VM_NAME}
    sudo virsh undefine ${VM_NAME}
    sudo rm -rf /var/lib/libvirt/images/$1
    sudo rm -rf /var/lib/libvirt/images/seed.iso
}


function qubinode_deploy_vyos_router_maintenance(){
    echo "Run the following commands"
    case ${product_maintenance} in
       create)
           vyos_variables
           echo "Creating router $4:::$5"
           exit 0
           create_router $5
           ;;
       destroy)
           destroy_router
           ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}
