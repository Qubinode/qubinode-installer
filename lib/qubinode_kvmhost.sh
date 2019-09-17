#!/bin/bash

# Ask if this host should be setup as a qubinode host
function ask_user_if_qubinode_setup () {
    setup_variables
    if [ "A${QUBINODE_SYSTEM}" == "A" ]
    then
        echo "This installer can setup your host as a KVM host and also a jumpbox for OpenShift install."
        echo "This is the default setup. Enter no to skip setting up your system as KVM host."
        echo "If you choose to install OpenShift, your host will be setup as a OpenShift jumpbox."
        echo ""
        echo ""
        confirm "Continue setting up a qubinode host? yes/no"
        if [ "A${response}" == "Ayes" ]
        then
            echo "Setting variabel to yes"
            sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
        elif [ "A${response}" == "Ano" ]
        then
            echo "Setting variabel to no"
            sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
        else
            echo "No action taken"
        fi
    fi
}
# Ensure RHEL is set to the supported release
function set_rhel_release () {
    prereqs
    RHEL_RELEASE=$(awk '/rhel_release/ {print $2}' "${vars_file}" |grep [0-9])
    RELEASE="Release: ${RHEL_RELEASE}"
    CURRENT_RELEASE=$(sudo subscription-manager release --show)

    if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
    then
        if [ "A${RELEASE}" != "A${CURRENT_RELEASE}" ]
        then
            echo "Setting RHEL to the supported release: ${RHEL_RELEASE}"
            sudo subscription-manager release --unset
            sudo subscription-manager release --set="${RHEL_RELEASE}"
        else
            echo "RHEL release is set to the supported release: ${CURRENT_RELEASE}"
        fi
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

   # Set KVM host ip info
    if grep '""' "${vars_file}"|grep -q kvm_host_ip
    then
        echo "Adding kvm_host_ip variable"
        sed -i "s#kvm_host_ip: \"\"#kvm_host_ip: "$IPADDR"#g" "${vars_file}"
    fi

    if grep '""' "${vars_file}"|grep -q kvm_host_gw
    then
        echo "Adding kvm_host_gw variable"
        sed -i "s#kvm_host_gw: \"\"#kvm_host_gw: "$GTWAY"#g" "${vars_file}"
    fi

    if grep '""' "${vars_file}"|grep -q kvm_host_mask_prefix
    then
        echo "Adding kvm_host_mask_prefix variable"
        sed -i "s#kvm_host_mask_prefix: \"\"#kvm_host_mask_prefix: "$NETMASK_PREFIX"#g" "${vars_file}"
    fi

    echo "setting kvm_host_interface varaible to $DEFAULT_INTERFACE"
    isInterface=$(awk '/kvm_host_interface/ { print $2}' "${vars_file}")
    if [ "A${isInterface}" == "A" ] || [ "A${isInterface}" == 'A""' ]
    then
        echo "Adding kvm_host_interface variable"
        sed -i "s#kvm_host_interface: \"\"#kvm_host_interface: "$DEFAULT_INTERFACE"#g" "${vars_file}"
    fi
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
    echo "Running qubinode_setup_kvm_host setup."
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
        if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
        then
            qubinode_rhsm_register
        fi
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
       if [ -f /usr/bin/ansible ]
       then
           ROLE_PRESENT=$(ansible-galaxy list | grep 'swygue.edge_host_setup')
           if [ "A${ROLE_PRESENT}" == "A" ]
           then
               qubinode_setup_ansible
           fi
       else
           qubinode_setup_ansible
       fi
   
       if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
       then
           ansible-playbook "${project_dir}/playbooks/setup_kvmhost.yml" || exit $?
           qubinode_check_libvirt_pool
       else
           qubinode_check_libvirt_pool
       fi
    else
        qubinode_setup_ansible
        qubinode_check_libvirt_pool
        echo "Installing required packages"
        sudo yum install -y -q -e 0 python3-dns libvirt-python python-lxml libvirt python-dns
    fi
}


function qubinode_check_kvmhost () {
    qubinode_networking
    echo "Validating the KVMHOST setup"
    DEFINED_LIBVIRT_NETWORK=$(awk '/vm_libvirt_net/ {print $2; exit}' "${vars_file}" | tr -d '"')
    DEFINED_VG=$(awk '/vg_name/ {print $2; exit}' "${vars_file}"| tr -d '"')
    DEFINED_BRIDGE=$(awk '/qubinode_bridge_name/ {print $2; exit}' "${vars_file}"| tr -d '"')
    BRIDGE_IP=$(sudo awk '/IPADDR=/ {print $2}' "/etc/sysconfig/network-scripts/ifcfg-${DEFINED_BRIDGE}")
    BRIDGE_INTERFACE=$(sudo brctl show "${DEFINED_BRIDGE}" | awk -v var="${DEFINED_BRIDGE}" '$1 == var {print $4}')
    
    if [ ! -f /usr/bin/virsh ]
    then
        qubinode_setup_kvm_host
    elif ! sudo virsh net-list --all --name | grep -q $DEFINED_LIBVIRT_NETWORK
    then
        qubinode_setup_kvm_host
    elif ! isRPMinstalled libvirt-python
    then
        qubinode_setup_kvm_host
    else
        KVM_HOST_MSG="KVM host is setup"
    fi

    if grep Fedora /etc/redhat-release
    then
        if ! isRPMinstalled python3-dns
        then
            qubinode_setup_kvm_host
        fi
    else
        if ! isRPMinstalled python-dns
        then
            qubinode_setup_kvm_host
        fi
    fi

    echo "Running qubinode checks: QUBINODE_SYSTEM=$QUBINODE_SYSTEM"
    if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
    then
        echo "qubinode network checks"
        if [ "A${HARDWARE_ROLE}" != "Alaptop" ]
        then
            echo "Running network checks"
            if ! sudo brctl show $DEFINED_BRIDGE > /dev/null 2>&1
            then
                qubinode_setup_kvm_host
            elif ! sudo vgs | grep -q $DEFINED_VG
            then
                qubinode_setup_kvm_host
            elif ! sudo lvscan | grep -q $DEFINED_VG
            then
                qubinode_setup_kvm_host
            elif [ "A${BRIDGE_IP}" == "A" ]
            then
                qubinode_setup_kvm_host
            elif [ "A${BRIDGE_INTERFACE}" != "${DEFINED_BRIDGE}" ]
            then
                qubinode_setup_kvm_host
            else
                KVM_HOST_MSG="KVM host is setup"
            fi
        fi
    fi
    
    echo $KVM_HOST_MSG
}
