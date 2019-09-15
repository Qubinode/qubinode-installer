#!/bin/bash

# Ensure RHEL is set to the supported release
function set_rhel_release () {
    prereqs
    RHEL_RELEASE=$(awk '/rhel_release/ {print $2}' "${vars_file}" |grep [0-9])
    RELEASE="Release: ${RHEL_RELEASE}"
    CURRENT_RELEASE=$(sudo subscription-manager release --show)

    if [ "A${RELEASE}" != "A${CURRENT_RELEASE}" ]
    then
        echo "Setting RHEL to the supported release: ${RHEL_RELEASE}"
        sudo subscription-manager release --unset
        sudo subscription-manager release --set="${RHEL_RELEASE}"
    else
       echo "RHEL release is set to the supported release: ${CURRENT_RELEASE}"
    fi
}

function qubinode_networking () {
    prereqs
    IPADDR=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    # HOST Gateway not currently in use
    GTWAY=$(ip route get 8.8.8.8 | awk -F"via " 'NR==1{split($2,a," ");print a[1]}')
    NETWORK=$(ip route | awk -F'/' "/$IPADDR/ {print \$1}")
    PTR=$(echo "$NETWORK" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'|sed 's/0.//g')

    if [ -f "${vars_file}" ]
    then
        DEFINED_BRIDGE=$(awk '/qubinode_bridge_name/ {print $2;exit 1 }' "${vars_file}")
    else
        DEFINED_BRIDGE=""
    fi

    CURRENT_DEFAULT_INTERFACE=$(sudo route | grep '^default' | awk '{print $8}')
    if [ "A${CURRENT_DEFAULT_INTERFACE}" == "A${DEFINED_BRIDGE}" ]
    then
      DEFAULT_INTERFACE=$(sudo brctl show "${DEFINED_BRIDGE}" | grep "${DEFINED_BRIDGE}"| awk '{print $4}')
    else
      DEFAULT_INTERFACE=$(ip route list | awk '/^default/ {print $5}')
    fi
    NETMASK_PREFIX=$(ip -o -f inet addr show $DEFAULT_INTERFACE | awk '{print $4}'|cut -d'/' -f2)
}


function qubinode_installer_preflight () {
    prereqs
}

function qubinode_check_libvirt_pool () {
    DEFINED_LIBVIRT_POOL=$(awk '/vm_libvirt_net/ {print $2; exit}' "${vars_file}"| tr -d '"')
    
    if sudo virsh net-list --all --name | grep -q "${DEFINED_LIBVIRT_POOL}"
    then
        echo "Using the defined libvirt network: ${DEFINED_LIBVIRT_POOL}"
    else
        echo "Could not find the defined libvirt network ${DEFINED_LIBVIRT_POOL}"
        echo "Will attempt to find and use the first bridge or nat libvirt network"
    
        nets=$(sudo virsh net-list --all --name)
        for item in $(echo $nets)
        do
            mode=$(sudo virsh net-dumpxml $item | awk -F"'" '/forward mode/ {print $2}')
            if [ "A${mode}" == "Abridge" ]
            then
                vm_libvirt_net="${item}"
                break
            elif [ "A${mode}" == "Anat" ]
            then
                vm_libvirt_net="${item}"
                break
            else
                echo "Did not find a bridge or nat libvirt network."
                echo "Please create one and try again."
                exit 1
            fi
        done
    
        confirm "Use the discovered libvirt net: *${vm_libvirt_net}* yes/no: "
        if [ "A${response}" == "Ayes" ]
        then
            echo "Updating libvirt network"
            sed -i "s/vm_libvirt_net:.*/vm_libvirt_net: "$vm_libvirt_net"/g" "${vars_file}"
        fi
    fi 
}


function qubinode_setup_kvm_host () {
    prereqs
    setup_variables
    setup_sudoers
    ask_user_input
    setup_user_ssh_key

    if [ "A${OS}" != "AFedora" ]
    then
        set_rhel_release
    fi

    if [ "A${HARDWARE_ROLE}" != "Alaptop" ]
    then
        qubinode_networking
        qubinode_rhsm_register
        qubinode_setup_ansible

       # check for host inventory file
       if [ ! -f "${hosts_inventory_dir}/hosts" ]
       then
           echo "Inventory file ${hosts_inventory_dir}/hosts is missing"
           echo "Please run qubinode-installer -m setup"
           echo ""
           exit 1
       fi
   
       # check for inventory directory
       if [ -f "${vars_file}" ]
       then
           if grep '""' "${vars_file}"|grep -q inventory_dir
           then
               echo "No value set for inventory_dir in ${vars_file}"
               echo "Please run qubinode-installer -m setup"
               echo ""
               exit 1
           fi
        else
           echo "${vars_file} is missing"
           echo "Please run qubinode-installer -m setup"
           echo ""
           exit 1
        fi
   
       # Check for ansible and ansible role
       ROLE_PRESENT=$(ansible-galaxy list | grep 'swygue.edge_host_setup')
       if [ ! -f /usr/bin/ansible ]
       then
           echo "Ansible is not installed"
           echo "Please run qubinode-installer -m ansible"
           echo ""
           exit 1
       elif [ "A${ROLE_PRESENT}" == "A" ]
       then
           echo "Required role swygue.edge_host_setup is missing."
           echo "Please run run qubinode-installer -m ansible"
           echo ""
           exit 1
       fi
   
       # future check for pool id
       #if grep '""' "${vars_file}"|grep -q openshift_pool_id
       #then
       ansible-playbook "${project_dir}/playbooks/setup_kvmhost.yml" || exit $?
       qubinode_check_libvirt_pool
    else
        qubinode_setup_ansible
        qubinode_check_libvirt_pool
    fi
}