#!/bin/bash

if [  $#  -ne  1  ]; then
    echo  "Usage: $0 vyos-1.4-rolling-202212280917-cloud-init-10G-qemu.qcow2" 
    exit 1
fi

IPADDR=$(sudo virsh net-dhcp-leases default | grep vyos-builder | awk '{print $5}' | sed 's/\/24//g')
cd $HOME
curl -OL http://${IPADDR}/$1
curl -OL http://${IPADDR}/seed.iso

VM_NAME=$(basename $HOME/vyos*.qcow2  | sed 's/.qcow2//g')
sudo mv $HOME/${VM_NAME}.qcow2 /var/lib/libvirt/images/
sudo mv $HOME/seed.iso /var/lib/libvirt/images/


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