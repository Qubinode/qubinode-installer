#!/bin/bash

function check_additional_storage () {
    # Load system wide variables
    setup_variables

    # Check if NVME device does not exist and present user with a choice of
    # disk to choose from if other disks are available.
    # If NVME device exist use it.
    if ! lsblk -dp | grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}'|grep -q nvme
    then
        printf "%s\n" "        ${yel}**NOTICE**${end}"
        printf "%s\n\n" " ${red}Did not find a NVME device${end}"
        printf "%s\n" " Qubinode recommends using a NVME device for"
        printf "%s\n" " storing the VMs disk. The device will be paritioned and"
        printf "%s\n\n" " a LVM volume created and mounted to /var/lib/libvirt/images."

        # Find all the disk devices
        TOTAL_DISKS=$(lsblk -dp | grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}'|grep -v nvme|wc -l)
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
                host_device=$disk
                printf "%s\n\n" ""
                printf "%s\n\n" " ${mag}Using disk: $disk${end}"
                sed -i "s/host_device: */host_device: $disk/g" "${vars_file}"
            else
                printf "%s\n\n" " ${mag}Exiting the install, please examine your disk choices and try again.${end}"
                exit 0
            fi
        else
            # If only one device is availabble inform the user and set
            # the host_device variable
            printf "%s\n\n" " ${grn}No additional storage device found.${end}"
            printf "%s\n" " There is no additional storage device available to"
            printf "%s\n" " dedicate to the libvirt storage pool that will be"
            printf "%s\n\n" " paritioned and mounted to /var/lib/libvirt/images."

            confirm " ${yel}Do you want to skip configuring additional storage?${end} ${blue}yes/no${end}"
            if [ "A${response}" == "Ayes" ]
            then
                printf "%s\n" ""
                printf "%s\n\n" "${mag} Setting create_lvm to no.${end}"
                sed -i "s/create_lvm:.*/create_lvm: "no"/g" "${vars_file}"
                #TODO; add a validation check to ensure the device is correct.
                host_device=$(lsblk -dp | grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}')
            else
                printf "%s\n\n" "${mag} There are no other options, exiting the install.${end}"
                exit
            fi
        fi
    else
        # Check if there are multiple NVME devices and present user with the
        # option to choose one to continue.
        TOTAL_NVME_DISKS=$(lsblk -dp | grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}'|grep nvme|wc -l)
        if [ $TOTAL_NVME_DISKS -gt 1 ]
        then
            printf "%s\n\n" " Multiple NVME devices found, please choose one? "
            declare -a all_disks=()
            mapfile -t all_disks < <(lsblk -dp | grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}'|grep nvme)
            createmenu "${all_disks[@]}"
            disk=($(echo "${selected_option}"))

            confirm "${yel}Continue with $disk?${end} ${blu}yes/no${end}"
            if [ "A${response}" == "Ayes" ]
            then
                printf "%s\n\n" ""
                printf "%s\n\n" " ${mag}Using disk: $disk${end}"
                sed -i "s/host_device: */host_device: $disk/g" "${vars_file}"
            else
                printf "%s\n\n" " ${mag}Exiting the install, please examine your disk choices and try again.${end}"
                exit 0
            fi
        else
            host_device=$(lsblk -dp | grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}'|grep nvme)
            sed -i "s/host_device: */host_device: $disk/g" "${vars_file}"
        fi
    fi

    # set variable disk required for check_disk_size
    DISK="${host_device}"
}

# Ask if this host should be setup as a qubinode host
function ask_user_if_qubinode_setup () {
    # ensure all required variables are setup
    setup_variables
    QUBINODE_SYSTEM=$(awk '/run_qubinode_setup:/ {print $2; exit}' "${vars_file}" | tr -d '"')
    # Ask user if this system should be a qubinode
    if [ "A${QUBINODE_SYSTEM}" == "A" ]
    then
        printf "%s\n" "   ${yel}********************************************${end}"
        printf "%s\n\n" "   ${yel}Qubinode Setup${end}"
        printf "%s\n" " The qubinode-installer configures your hardware as a KVM host"
        printf "%s\n\n" " otherwise referred as ${grn}Qubinode${end}."

        printf "%s\n" " You can choose not to configure this as a Qubinode if the following are true: "
        printf "%s\n" "  ${mag}(*)${end} ${blu}A libvirt bridge network is already setup.${end}"
        printf "%s\n" "  ${mag}(*)${end} ${blu}The system is already setup to function as a KVM host.${end}"
        printf "%s\n\n" "  ${mag}(*)${end} ${blu}The system is already registered to Red Hat.${end}"

        confirm "${yel} Do you want to continue as a Qubinode?${end} ${blu}yes/no ${end}"

        if [ "A${response}" == "Ayes" ]
        then
            # Set varaible to configure storage and networking
            sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
        else
            # Set varaible not to configure storage and networking
            sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
            printf "%s\n\n" ""
            printf "%s\n" "${cyn} You choose not to setup this system as a Qubinode.${end}"
            printf "%s\n" "${cyn} Please understand that by choosing this route you are${end}"
            printf "%s\n" "${cyn} taking ownership of setting up the system to function as${end}"
            printf "%s\n" "${cyn} kvm/libvirt host. Also, support for this setup is limited.${end}"
            printf "%s\n" "${yel} However, pull request are very welcome.${end}"
            printf "%s\n\n" "${cyn} We will now attempt to verify your libvirt storage and network.${end}"

        fi
    fi
}

function check_libvirt_pool () {
    # Verify storage and network when not setting up Qubinode
    QUBINODE_SYSTEM=$(awk '/run_qubinode_setup:/ {print $2; exit}' "${vars_file}" | tr -d '"')
    CHECK_LIBVIRT_POOL=$(awk '/libvirt_pool_name_check:/ {print $2; exit}' "${vars_file}" | tr -d '"')
    if [ "A${CHECK_LIBVIRT_POOL}" == "Ayes" ]
    then
        # Check libvirt storage
        LIBVIRT_POOLS=$(sudo virsh pool-list --autostart | awk '/active/ {print $1}'| grep -v qbn | wc -l)
        LIBVIRT_POOLS="${LIBVIRT_POOLS:-0}"
        if [ $LIBVIRT_POOLS -gt 1 ]
        then
            #printf "%s\n\n" " ${mag}Found multiple libvirt pools${end}"
            printf "%s\n" " ${yel}Found multiple libvirt pools, choose one to continue: ${end}"
            declare -a all_pools=()
            mapfile -t all_pools < <(sudo virsh pool-list --autostart | awk '/active/ {print $1}'| grep -v qbn)
            createmenu "${all_pools[@]}"
            POOL=($(echo "${selected_option}"))

            printf "%s\n" " Setting libvirt_pool_name to $POOL"
            sed -i "s/libvirt_pool_name:.*/libvirt_pool_name: "$POOL"/g" "${vars_file}"
            sed -i "s/libvirt_pool_name_check:.*/libvirt_pool_name_check: no/g" "${vars_file}"
        elif [ $LIBVIRT_POOLS -eq 0 ]
        then
            printf "%s\n\n" " ${red}No libvirt pool found, please resolve this issue and try again.${end}"
            exit 2
        else
            POOL=$(sudo virsh pool-list --autostart | awk '/active/ {print $1}'| grep -v qbn)
            if [ "A${POOL}" != "default" ]
            then
                printf "%s\n" " Setting libvirt_pool_name to $POOL"
                sed -i "s/libvirt_pool_name:.*/libvirt_pool_name: "$POOL"/g" "${vars_file}"
                sed -i "s/libvirt_pool_name_check:.*/libvirt_pool_name_check: no/g" "${vars_file}"
            fi
        fi
        # Check the pool capacity
        POOL_CAPACITY=$(sudo virsh pool-dumpxml "${POOL}"| grep capacity | grep -Eo "[[:digit:]]{1,100}")
    fi
}

function check_libvirt_network () {
    CHECK_LIBVIRT_NET=$(awk '/vm_libvirt_net_check:/ {print $2; exit}' "${vars_file}" | tr -d '"')
    if [ "A${CHECK_LIBVIRT_NET}" == "Ayes" ]
    then
        # Check libvirt network
        LIBVIRT_NETS=$(sudo virsh net-list --autostart | awk '/active/ {print $1}'| wc -l)
        LIBVIRT_NETS="${LIBVIRT_NETS:-0}"
        if [ $LIBVIRT_NETS -gt 1 ]
        then
            printf "%s\n" "${yel} Found multiple libvirt networks, choose one to continue: ${end}"
            declare -a all_networks=()
            mapfile -t all_networks < <(sudo virsh net-list --autostart | awk '/active/ {print $1}')
            createmenu "${all_networks[@]}"
            NETWORK=($(echo "${selected_option}"))

            printf "%s\n" " Setting vm_libvirt_net to $NETWORK"
            sed -i "s/vm_libvirt_net:.*/vm_libvirt_net: "$NETWORK"/g" "${vars_file}"
            sed -i "s/vm_libvirt_net_check:.*/vm_libvirt_net_check: no/g" "${vars_file}"
        elif [ $LIBVIRT_NETS -eq 0 ]
        then
            printf "%s\n\n" " ${red}No libvirt network found, please resolve this issue and try again.${end}"
            exit 2
        else
            NETWORK=$(sudo virsh net-list --autostart | awk '/active/ {print $1}')
            if [ "A${NETWORK}" != "qubinet" ]
            then
               printf "%s\n" " Setting vm_libvirt_net to $NETWORK"
               sed -i "s/vm_libvirt_net:.*/vm_libvirt_net: $NETWORK/g" "${vars_file}"
               sed -i "s/vm_libvirt_net_check:.*/vm_libvirt_net_check: no/g" "${vars_file}"
            fi
        fi
    fi
}

function qubinode_system_auto_install () {
    if [ "A${openshift_auto_install}" != "Atrue" ]
    then
        QUBINODE_SYSTEM=$(awk '/run_qubinode_setup:/ {print $2; exit}' "${vars_file}" | tr -d '"')
    else
        # Set varaible to configure storage and networking
        response=yes
        sed -i "s/run_qubinode_setup:.*/run_qubinode_setup: "$response"/g" "${vars_file}"
        check_additional_storage
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
    KVM_HOST_IPADDR=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    # HOST Gateway not currently in use
    KVM_HOST_GTWAY=$(ip route get 8.8.8.8 | awk -F"via " 'NR==1{split($2,a," ");print a[1]}')
    NETWORK=$(ip route | awk -F'/' "/$KVM_HOST_IPADDR/ {print \$1}")
    PTR=$(echo "$NETWORK" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'|sed 's/0.//g')

    # ask user for their IP network and use the default
    if cat "${vars_file}"|grep -q changeme.in-addr.arpa
    then
        #read -p " ${mag}Enter your IP Network or press${end} ${yel}[ENTER]${end} ${mag}for the default [$NETWORK]: ${end}" network
        #network=${network:-"${NETWORK}"}
        network="${NETWORK}"
        PTR=$(echo "$NETWORK" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'|sed 's/0.//g')
        sed -i "s/changeme.in-addr.arpa/"$PTR"/g" "${vars_file}"
    fi

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
      KVM_HOST_PRIMARY_INTERFACE=$(ip route list | awk '/^default/ {print $5}')
    fi

    KVM_HOST_MASK_PREFIX=$(ip -o -f inet addr show $CURRENT_KVM_HOST_PRIMARY_INTERFACE | awk '{print $4}'|cut -d'/' -f2)
    mask=$(ip -o -f inet addr show $CURRENT_KVM_HOST_PRIMARY_INTERFACE|awk '{print $4}')
    KVM_HOST_NETMASK=$(ipcalc -m $mask|awk -F= '{print $2}')

   # Set KVM host ip info
    iSkvm_host_netmask=$(awk '/^kvm_host_netmask/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_netmask}" == "A" ]] || [[ "A${iSkvm_host_netmask}" == 'A""' ]]
    then
        #printf "\n Updating the kvm_host_netmask to ${yel}$KVM_HOST_NETMASK${end}"
        sed -i "s#kvm_host_netmask:.*#kvm_host_netmask: "$KVM_HOST_NETMASK"#g" "${vars_file}"
    fi

    iSkvm_host_ip=$(awk '/^kvm_host_ip/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_ip}" == "A" ]] || [[ "A${iSkvm_host_ip}" == 'A""' ]]
    then
        #echo "Updating the kvm_host_ip to $KVM_HOST_IPADDR"
        sed -i "s#kvm_host_ip:.*#kvm_host_ip: "$KVM_HOST_IPADDR"#g" "${vars_file}"
    fi

    iSkvm_host_gw=$(awk '/^kvm_host_gw/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_gw}" == "A" ]] || [[ "A${iSkvm_host_gw}" == 'A""' ]]
    then
        #echo "Updating the kvm_host_gw to $KVM_HOST_GTWAY"
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
        #echo "Updating the kvm_host_interface to $KVM_HOST_PRIMARY_INTERFACE"
        sed -i "s#kvm_host_interface:.*#kvm_host_interface: "$KVM_HOST_PRIMARY_INTERFACE"#g" "${vars_file}"
    fi

    iSkvm_host_macaddr=$(awk '/^kvm_host_macaddr/ { print $2}' "${vars_file}")
    if [[ "A${iSkvm_host_macaddr}" == "A" ]] || [[ "A${iSkvm_host_macaddr}" == 'A""' ]]
    then
        foundmac=$(ip addr show $KVM_HOST_PRIMARY_INTERFACE | grep link | awk '{print $2}' | head -1)
        #echo "Updating the kvm_host_macaddr to ${foundmac}"
        sed -i "s#kvm_host_macaddr:.*#kvm_host_macaddr: '"${foundmac}"'#g" "${vars_file}"
    fi

    # Check Network
    #qubinode_check_libvirt_net
}


function qubinode_check_libvirt_net () {
    DEFINED_LIBVIRT_NETWORK=$(awk '/vm_libvirt_net/ {print $2; exit}' "${vars_file}"| tr -d '"')

    if sudo virsh net-list --all --name | grep -q "${DEFINED_LIBVIRT_NETWORK}"
    then
        NONOTHING=yes
        #printf "%s\n" " Using the defined libvirt network: ${DEFINED_LIBVIRT_NETWORK}"
    else
        printf "%s\n" " Could not find the defined libvirt network ${DEFINED_LIBVIRT_NETWORK}"
        printf "%s\n" " Will attempt to find and use the first bridge or nat libvirt network"

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
                echo " Did not find a bridge or nat libvirt network."
                echo " Please create one and try again."
                exit 1
            fi
        done

        confirm " Use the discovered libvirt net: ${blu}${vm_libvirt_net}${end} ${yel}yes/no${end}: "
        if [ "A${response}" == "Ayes" ]
        then
            printf "%s\n" " Updating libvirt network"
            sed -i "s/vm_libvirt_net:.*/vm_libvirt_net: "$vm_libvirt_net"/g" "${vars_file}"
        fi
    fi
}


function qubinode_setup_kvm_host () {
    # set variable to enable prompting user if they want to
    # setup host as a qubinode
    qubinode_maintenance_opt="host"

    # Ensure the base setup is done
    setup_variables
    if [ "A${base_setup_completed}" == "Ano" ]
    then
       qubinode_base_requirements
    fi    

    # Check if we should setup qubinode
    QUBINODE_SYSTEM=$(awk '/run_qubinode_setup/ {print $2; exit}' "${vars_file}" | tr -d '"')

    if [ "A${OS}" != "AFedora" ]
    then
        set_rhel_release
    fi

    if [ "A${HARDWARE_ROLE}" != "Alaptop" ]
    then
       # Check for ansible and required role
       check_for_required_role swygue.edge_host_setup

       if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
       then
           printf "%s\n" " ${blu}Setting up qubinode system${end}"
           ansible-playbook "${project_dir}/playbooks/setup_kvmhost.yml" || exit $?
           #qubinode_check_libvirt_net
       else
           printf "%s\n" " ${blu}not qubinode system${end}"
           #qubinode_check_libvirt_net
       fi
    else
        echo "Installing required packages"
        sudo yum install -y -q -e 0 python3-dns libvirt-python python-lxml libvirt python-dns
    fi

    sed -i "s/qubinode_installer_host_completed:.*/qubinode_installer_host_completed: yes/g" "${vars_file}"
    printf "\n\n${yel}    ***************************${end}\n"
    printf "${yel}    *   KVM Host Setup Complete   *${end}\n"
    printf "${yel}    ***************************${end}\n\n"
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
