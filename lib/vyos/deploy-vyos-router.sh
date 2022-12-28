#!/bin/bash

if [  $#  -ne  2 ]; then
    echo  "Usage: $0 create vyos-1.4-rolling-202212280917-cloud-init-10G-qemu.qcow2" 
    exit 1
fi

function create_router(){
   IPADDR=$(sudo virsh net-dhcp-leases default | grep vyos-builder | awk '{print $5}' | sed 's/\/24//g')
cd $HOME
curl -OL http://${IPADDR}/$1
VM_NAME=$(basename $HOME/$1  | sed 's/.qcow2//g')
sudo mv $HOME/${VM_NAME}.qcow2 /var/lib/libvirt/images/
curl -OL http://${IPADDR}/$VM_NAME-seed.iso
sudo mv $HOME/$VM_NAME-seed.iso /var/lib/libvirt/images/seed.iso


sudo virt-install -n vyos_r1 \
   --ram 4096 \
   --vcpus 2 \
   --cdrom /var/lib/libvirt/images/seed.iso \
   --os-variant debian10 \
   --network bridge=qubibr0,model=virtio\
    --network network=test \
    --network network=test2 \
   --graphics vnc \
   --hvm \
   --virt-type kvm \
   --disk path=/var/lib/libvirt/images/$VM_NAME.qcow2,bus=virtio \
   --import \
   --noautoconsole
}

function destroy_router(){
    sudo virsh destroy vyos_r1
    sudo virsh undefine vyos_r1
    sudo rm -rf /var/lib/libvirt/images/$1
    sudo rm -rf /var/lib/libvirt/images/seed.iso
}

if [ $1  ==  "create"  ]; then
    create_router $2
elif [ $1  ==  "destroy"  ]; then
    destroy_router $2
else
    echo "Usage: $0 create|destroy"
fi