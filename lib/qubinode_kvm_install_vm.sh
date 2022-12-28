#!/bin/bash 
# https://github.com/giovtorres/kvm-install-vm
# A bash wrapper around virt-install to build virtual machines on a local KVM hypervisor. You can run it as a normal user which will use qemu:///session to connect locally to your KVM domains.
# ./qubinode-installer -p kvm_install_vm
# works on fedora 37 
setup_variables
product_in_use=kvm-install-vm
source "${project_dir}/lib/qubinode_utils.sh"

############################################
## @description - Install and configure kvm-install-vm
## @param - none
## @return - none
############################################
function qubinode_setup_kvm_install_vm(){
    echo "Configure kvm-install-vm"
    sudo sed -i  's|hosts:.*|hosts:      files libvirt libvirt_guest dns myhostname|g' /etc/nsswitch.conf
    sudo curl -L https://raw.githubusercontent.com/giovtorres/kvm-install-vm/master/kvm-install-vm -o /usr/bin/kvm-install-vm
    sudo chmod +x /usr/bin/kvm-install-vm
    kvm-install-vm
}

function qubinode_kvm_install_vm_maintenance(){
    echo "function qubinode_kvm_install_vm_maintenance"
}

