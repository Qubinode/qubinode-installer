#!/bin/bash

function teardown_idm () {
    if sudo virsh list --all | grep -q qbn-dns01
    then
        ./qubinode-installer -p idm -d
    fi
}

function teardown_ocp3 () {
    if sudo virsh list --all | grep -q qbn-ocp3-node01
    then
        ./qubinode-installer -p ocp3 -d
    fi
}

function teardown_ocp4 () {
    if sudo virsh list --all | grep -q master-0
    then
        ./qubinode-installer -p ocp4 -d
    fi
}

function teardown_tower () {
    if sudo virsh list --all | grep -q tower
    then
        ./qubinode-installer -p tower -d
    fi
}

function teardown_satellite () {
    if sudo virsh list --all | grep -q tower
    then
        ./qubinode-installer -p satellite -d
    fi
}

function isvmRunning () {
    sudo virsh list |grep $vm|awk '/running/ {print $2}'
}

function forceVMteardown () {
    for vm in $(sudo virsh list --name --all)
    do
        isvmRunning | while read VM
        do
            sudo virsh shutdown $vm
            sleep 3
        done
        sudo virsh destroy $vm
        sudo virsh undefine $vm --remove-all-storage
    done
}

function removeStorage () {
    #libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/playbooks/vars/kvm_host.yml")
    while sudo systemctl list-units --type=service | grep -q libvirtd
    do
        sudo systemctl stop libvirtd
    done

    if ! sudo systemctl list-units --type=service | grep -q libvirtd
    then
        sudo umount /var/lib/libvirt/images
        sudo vgremove --force -y vg_qubi
    fi
}

teardown_idm
teardown_ocp3
teardown_ocp4
teardown_tower
teardown_satellite
forceVMteardown
removeStorage

printf "%s\n" " System is ready for rebuild"
exit 0
