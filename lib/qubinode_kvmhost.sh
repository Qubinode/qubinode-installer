#!/bin/bash

# Ask if this host should be setup as a qubinode host
function ask_user_if_qubinode_setup () {
    # ensure all required variables are setup
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
            #"Setting variabel to yes"
            sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
        elif [ "A${response}" == "Ano" ]
        then
            #"Setting variabel to no"
            sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
        else
            echo "No action taken"
        fi
    fi
}
# Ensure RHEL is set to the supported release
function set_rhel_release () {
    product_requirements
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
    product_requirements
    KVM_HOST_IPADDR=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    # HOST Gateway not currently in use
    KVM_HOST_GTWAY=$(ip route get 8.8.8.8 | awk -F"via " 'NR==1{split($2,a," ");print a[1]}')
    NETWORK=$(ip route | awk -F'/' "/$KVM_HOST_IPADDR/ {print \$1}")
    PTR=$(echo "$NETWORK" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'|sed 's/0.//g')

    if [ -f "${vars_file}" ]
    then
        DEFINED_BRIDGE=$(awk '/qubinode_bridge_name/ {print $2;exit 1 }' "${vars_file}")
    else
        DEFINED_BRIDGE=""
    fi
    
    CURRENT_KVM_HOST_PRIMARY_INTERFACE=$(sudo route | grep '^default' | awk '{print $8}')
    if [ "A${CURRENT_KVM_HOST_PRIMARY_INTERFACE}" == "A${DEFINED_BRIDGE}" ]
    then
      KVM_HOST_PRIMARY_INTERFACE=$(sudo brctl show "${DEFINED_BRIDGE}" | grep "${DEFINED_BRIDGE}"| awk '{print $4}')
    else
      echo "No bridge detected, using regular interface"
      KVM_HOST_PRIMARY_INTERFACE=$(ip route list | awk '/^default/ {print $5}')
    fi

    KVM_HOST_MASK_PREFIX=$(ip -o -f inet addr show $CURRENT_KVM_HOST_PRIMARY_INTERFACE | awk '{print $4}'|cut -d'/' -f2)
    mask=$(ip -o -f inet addr show $CURRENT_KVM_HOST_PRIMARY_INTERFACE|awk '{print $4}')
    KVM_HOST_NETMASK=$(ipcalc -m $mask|awk -F= '{print $2}')

   # Set KVM host ip info
    iSkvm_host_netmask=$(awk '/^kvm_host_netmask/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_netmask}" == "A" ]] || [[ "A${iSkvm_host_netmask}" == 'A""' ]]
    then
        echo "Updating the kvm_host_netmask to $KVM_HOST_NETMASK"
        sed -i "s#kvm_host_netmask:.*#kvm_host_netmask: "$KVM_HOST_NETMASK"#g" "${vars_file}"
    fi

    iSkvm_host_ip=$(awk '/^kvm_host_ip/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_ip}" == "A" ]] || [[ "A${iSkvm_host_ip}" == 'A""' ]]
    then
        echo "Updating the kvm_host_ip to $KVM_HOST_IPADDR"
        sed -i "s#kvm_host_ip:.*#kvm_host_ip: "$KVM_HOST_IPADDR"#g" "${vars_file}"
    fi

    iSkvm_host_gw=$(awk '/^kvm_host_gw/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_gw}" == "A" ]] || [[ "A${iSkvm_host_gw}" == 'A""' ]]
    then
        echo "Updating the kvm_host_gw to $KVM_HOST_GTWAY"
        sed -i "s#kvm_host_gw:.*#kvm_host_gw: "$KVM_HOST_GTWAY"#g" "${vars_file}"
    fi

    iSkvm_host_mask_prefix=$(awk '/^kvm_host_mask_prefix/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_mask_prefix}" == "A" ]] || [[ "A${iSkvm_host_mask_prefix}" == 'A""' ]]
    then
        #echo "Updating the kvm_host_mask_prefix to $KVM_HOST_MASK_PREFIX"
        sed -i "s#kvm_host_mask_prefix:.*#kvm_host_mask_prefix: "$KVM_HOST_MASK_PREFIX"#g" "${vars_file}"
    fi

    iSkvm_host_interface=$(awk '/^kvm_host_interface/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_interface}" == "A" ]] || [[ "A${iSkvm_host_interface}" == 'A""' ]]
    then
        echo "Updating the kvm_host_interface to $KVM_HOST_PRIMARY_INTERFACE"
        sed -i "s#kvm_host_interface:.*#kvm_host_interface: "$KVM_HOST_PRIMARY_INTERFACE"#g" "${vars_file}"
    fi
}


function qubinode_check_libvirt_net () {
    DEFINED_LIBVIRT_NETWORK=$(awk '/vm_libvirt_net/ {print $2; exit}' "${vars_file}"| tr -d '"')
    
    if sudo virsh net-list --all --name | grep -q "${DEFINED_LIBVIRT_NETWORK}"
    then
        echo "Using the defined libvirt network: ${DEFINED_LIBVIRT_NETWORK}"
    else
        echo "Could not find the defined libvirt network ${DEFINED_LIBVIRT_NETWORK}"
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
    echo "Running qubinode_setup_kvm_host function"

    # set variable to enable prompting user if they want to 
    # setup host as a qubinode
    qubinode_maintenance_opt="host"

    # run functions
    product_requirements
    setup_variables
    setup_sudoers
    ask_user_input
    setup_user_ssh_key

    # Check if we should setup qubinode
    QUBINODE_SYSTEM=$(awk '/run_qubinode_setup/ {print $2; exit}' "${vars_file}" | tr -d '"')

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
   
       # Check for ansible and required role
       check_for_required_role swygue.edge_host_setup
   
       if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
       then
           echo "Setting up qubinode system"
           ansible-playbook "${project_dir}/playbooks/setup_kvmhost.yml" || exit $?
           qubinode_check_libvirt_net
       else
           echo "not qubinode system"
           qubinode_check_libvirt_net
       fi
    else
       echo "Some other option"
        qubinode_setup_ansible
        qubinode_check_libvirt_net
        echo "Installing required packages"
        sudo yum install -y -q -e 0 python3-dns libvirt-python python-lxml libvirt python-dns
    fi

    printf "\n\n***************************\n"
    printf "* KVM Host Setup Complete  *\n"
    printf "***************************\n\n"

}


function qubinode_check_kvmhost () {
    qubinode_networking
    echo "Validating the KVMHOST setup"
    DEFINED_LIBVIRT_NETWORK=$(awk '/vm_libvirt_net/ {print $2; exit}' "${vars_file}" | tr -d '"')
    DEFINED_VG=$(awk '/vg_name/ {print $2; exit}' "${vars_file}"| tr -d '"')
    DEFINED_BRIDGE=$(awk '/qubinode_bridge_name/ {print $2; exit}' "${vars_file}"| tr -d '"')
    BRIDGE_IP=$(sudo awk -F'=' '/IPADDR=/ {print $2}' "/etc/sysconfig/network-scripts/ifcfg-${DEFINED_BRIDGE}")
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

    # Running qubinode checks
    if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
    then
        echo "qubinode network checks"
        BRIDGE_SLAVE=$(sudo egrep -Rl "${DEFINED_BRIDGE}_slave" /etc/sysconfig/network-scripts/ifcfg-*)
        BRIDGE_SLAVE_NIC=$(sudo awk -F'=' '/DEVICE/ {print $2}' $BRIDGE_SLAVE)
        if [ "A${HARDWARE_ROLE}" != "Alaptop" ]
        then
            echo "Running network checks"
            if ! sudo brctl show $DEFINED_BRIDGE > /dev/null 2>&1
            then
                echo "The required bridge $DEFINED_BRIDGE is not setup"
                qubinode_setup_kvm_host
            elif ! sudo vgs | grep -q $DEFINED_VG
            then
                echo "The required LVM volgume group $DEFINED_VG is not setup"
                qubinode_setup_kvm_host
            elif ! sudo lvscan | grep -q $DEFINED_VG
            then
                echo "The required LVM volume is not setup"
                qubinode_setup_kvm_host
            elif [ "A${BRIDGE_IP}" == "A" ]
            then
                echo "The require brdige IP $BRIDGE_IP is not defined"
                qubinode_setup_kvm_host
            elif [ "A${BRIDGE_INTERFACE}" != "A${BRIDGE_SLAVE_NIC}" ]
            then
                echo "The required bridge interface "${DEFINED_BRIDGE}" is not setup"
                qubinode_setup_kvm_host
            else
                KVM_HOST_MSG="KVM host is setup"
            fi
         else
            KVM_HOST_MSG="KVM host is setup"
        fi
    else
        KVM_HOST_MSG="KVM host is setup"
    fi
    
    echo $KVM_HOST_MSG
}
