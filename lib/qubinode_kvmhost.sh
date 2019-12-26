#!/bin/bash

# Ask if this host should be setup as a qubinode host
function ask_user_if_qubinode_setup () {
    # ensure all required variables are setup
    setup_variables

    QUBINODE_SYSTEM=$(awk '/run_qubinode_setup:/ {print $2; exit}' "${vars_file}" | tr -d '"')
    if [ "A${openshift_auto_install}" != "Atrue" ]
    then
 
        # Ask user if this system should be a qubinode
        if [ "A${QUBINODE_SYSTEM}" == "A" ]
        then
            printf "%s\n" "   ${yel}********************************************${end}"
            printf "%s\n" "   ${yel}Networking, Storage and Subscription Manager${end}"
            printf "\n The qubinode-installer configures your hardware as a KVM host"
            printf "\n otherwise referred as ${grn}Qubinode${end}."

            printf "\n\n You can choose not to configure this as a Qubinode if the following are true: "
            printf "\n\n  ${mag}(*)${end} ${blu}A libvirt bridge network is already setup.${end}"
            printf "\n  ${mag}(*)${end} ${blu}The system is already registered to Red Hat.${end}\n\n"

            printf "\n You can also choose not to if you do not have a NVME device"
            printf "\n to use for storing VM disks. \n\n"

            confirm "${yel}Do you want to continue as a Qubinode?${end} ${blu}yes/no ${end}"

            if [ "A${response}" == "Ayes" ]
            then
                # Set varaible to configure storage and networking
                sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
            else
                # Set varaible not to configure storage and networking
                sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
            fi
        fi

        # Verify storage and network when no setting up Qubinode
        if [ "A${QUBINODE_SYSTEM}" == "no" ]
        then

            # Check libvirt storage
            LIBVIRT_POOLS=$(sudo virsh pool-list --autostart | awk '/active/ {print $1}'| grep -v qbn | wc -l)
           if [ $LIBVIRT_POOLS -gt 1 ]
           then
               printf "\n\n${mag}Libvirt Pools${end}"
               printf "\n${mag}*************${end}"
               printf "\n${mag}Found multiple libvirt pools${end}"
               printf "\n${yel}Choose one to continue: ${end}\n\n"
               declare -a all_pools=()
               mapfile -t all_pools < <(sudo virsh pool-list --autostart | awk '/active/ {print $1}'| grep -v qbn)
               createmenu "${all_pools[@]}"
               POOL=($(echo "${selected_option}"))

               echo "Setting libvirt_pool_name to $POOL"
               sed -i "s/libvirt_pool_name:.*/libvirt_pool_name: "$POOL"/g" "${vars_file}"
           else
               POOL=$(sudo virsh pool-list --autostart | awk '/active/ {print $1}'| grep -v qbn)
               if [ "A${POOL}" != "default" ]
               then
                   echo "Setting libvirt_pool_name to $POOL"
                   sed -i "s/libvirt_pool_name:.*/libvirt_pool_name: "$POOL"/g" "${vars_file}"
               fi
           fi

           # Check libvirt network
           LIBVIRT_NETS=$(sudo virsh net-list --autostart | awk '/active/ {print $1}'| grep -v qubi|grep -v ocp42| wc -l)
           if [ $LIBVIRT_NETS -gt 1 ]
           then
               printf "\n\n${mag}Libvirt Networks${end}"
               printf "\n${mag}*************${end}"
               printf "\n${mag}Found multiple libvirt networks${end}"
               printf "\n${yel}Choose one to continue: ${end}\n\n"
               declare -a all_networks=()
               mapfile -t all_networks < <(sudo virsh net-list --autostart | awk '/active/ {print $1}'| grep -v qubi|grep -v ocp42)
               createmenu "${all_networks[@]}"
               NETWORK=($(echo "${selected_option}"))

               echo "Setting libvirt_pool_name to $NETWORK"
               sed -i "s/vm_libvirt_net:.*/vm_libvirt_net: "$NETWORK"/g" "${vars_file}"
           else
               NETWORK=$(sudo virsh pool-list --autostart | awk '/active/ {print $1}'| grep -v qbn)
               if [ "A${NETWORK}" != "qubinet" ]
               then
                   echo "Setting libvirt_pool_name to $NETWORK"
                   sed -i "s/libvirt_pool_name:.*/libvirt_pool_name: "$NETWORK"/g" "${vars_file}"
               fi
           fi

        else
            # check for nvme
            TOTAL_DISKS=$(lsblk -dp | grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}'|wc -l)
            if ! lsblk -dp | grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}'|grep -q nvme
            then
                printf "%s\n" "        ${yel}**NOTICE**${end}"
                printf "%s\n\n" " ${red}Did not find a NVME device${end}"
                printf "%s\n" " Qubinode recommends using a NVME device for"
                printf "%s\n" " storing the VMs disk. The device will be paritioned and"
                printf "%s\n\n" " a LVM volume created and mounted to /var/lib/libvirt/images."

                if [ $TOTAL_DISKS -gt 1 ]
                then
                    printf "%s\n\n" " If you are using a none NVME device, please choose from the list below."
                    declare -a all_disks=()
                    mapfile -t all_disks < <(lsblk -dp | grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}'|grep -v nvme)
                    createmenu "${all_disks[@]}"
                    disk=($(echo "${selected_option}"))

                    confirm "${yel}Continue with $disk?${end} ${blu}yes/no${end}"
                    if [ "A${response}" == "Ayes" ]
                    then
                         printf "%s\n\n" ""
                         printf "%s\n\n" " ${mag}Using disk: $disk${end}"
                         sed -i "s/host_device: */host_device: $disk/g" "${varsfile}"
                    else
                         printf "%s\n\n" " ${mag}Exiting the install, please examine your disk choices and try again.${end}"
                         exit 0
                    fi
                else
                    printf "%s\n\n" " ${grn}No additional storage device found.${end}"
                    printf "%s\n" " You can skip this and use the default"
                    printf "%s\n\n" " disk where /var/lib/libvirt/images is mounted."

                    confirm "${yel}Do you want to skip configuring additional storage?${end} ${blue}yes/no${end}"
                    if [ "A${response}" == "Ayes" ]
                    then
                         printf "%s\n" ""
                         printf "%s\n\n" "${mag} Setting create_lvm to no.${end}"
                         #sed -i "s/create_lvm:.*/create_lvm: "no"/g" "${varsfile}"
                    else
                        printf "%s\n\n" "${mag} There are no other options, exiting the install.${end}"
                    fi

                fi
            fi
        fi
    else
        # Set varaible to configure storage and networking
        response=yes
        sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
    fi
}

# Ensure RHEL is set to the supported release
function set_rhel_release () {
    qubinode_required_prereqs
    RHEL_RELEASE=$(awk '/rhel_release/ {print $2}' "${vars_file}" |grep [0-9])
    RELEASE="Release: ${RHEL_RELEASE}"
    CURRENT_RELEASE=$(sudo subscription-manager release --show)

    if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
    then
        if [ "A${RELEASE}" != "A${CURRENT_RELEASE}" ]
        then
            printf "\n\nSetting RHEL to the supported release: ${RHEL_RELEASE}"
            sudo subscription-manager release --unset
            sudo subscription-manager release --set="${RHEL_RELEASE}"
        else
            printf "\n\nRHEL release is set to the supported release: ${CURRENT_RELEASE}"
        fi
    fi
}

function qubinode_networking () {
    qubinode_required_prereqs
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

    iSkvm_host_macaddr=$(awk '/^kvm_host_macaddr/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_macaddr}" == "A" ]] || [[ "A${iSkvm_host_macaddr}" == 'A""' ]]
    then
        foundmac=$(ip addr show $KVM_HOST_PRIMARY_INTERFACE | grep link | awk '{print $2}' | head -1)
        echo "Updating the kvm_host_macaddr to ${foundmac}"
        sed -i "s#kvm_host_macaddr:.*#kvm_host_macaddr: '"${foundmac}"'#g" "${vars_file}"
    fi

    #host_device
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
    qubinode_required_prereqs
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
