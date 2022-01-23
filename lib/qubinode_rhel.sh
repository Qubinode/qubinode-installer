#!/bin/bash
function qubinode_rhel_global_vars () {
    ## This function sets up globally required variables
    setup_variables

    ## Gather networking information about the KVM host
    qubinode_networking

    ## Varibles required for deploying RHEL
    RHEL_VM_PLAY="${project_dir}/playbooks/rhel.yml"
    rhel_vars_file="${project_dir}/playbooks/vars/rhel.yml"
    rhel_major=$(sed -rn 's/.*([0-9])\.[0-9].*/\1/p' /etc/redhat-release)
    product_in_use=rhel
    prefix=$(awk '/instance_prefix/ {print $2;exit}' "${vars_file}")
    default_rhel_release=$(awk -v var="rhel${rhel_major}_version" '$0 ~ var {print $2;exit}' "${vars_file}")
    suffix=rhel

    # define the rhel source vars to be set later on
    local qubinode_vm_sizes_source
    local qubinode_vm_template_source="${project_dir}/samples/rhel_vms/rhel_template.yml"

    # remove existing rhel vars file
    test -f "${rhel_vars_file}" && rm -f "${rhel_vars_file}"

    # copy VM template to main vars file
    cp "${qubinode_vm_template_source}" "${rhel_vars_file}"

    # Check for user provided variables
    for var in "${product_options[@]}"
    do
       export $var
    done

    # Check for user provided name for the vm
    if [ "${name:-none}" != "none" ]
    then
        local generated_name="${name}${instance_id}"
        qubinode_generate_instance_id "$generated_name"
        rhel_server_hostname="${generated_name}"
    else
        qubinode_generate_instance_id "${prefix}-${suffix}${rhel_major}-"
        local generated_name="${prefix}-${suffix}${rhel_major}-${instance_id}"
        rhel_server_hostname="${generated_name}"
    fi

    # Required VM attributes when deploying a VM
    if [ "${teardown:-none}" != "true" ]
    then

	# Takes the RHEL release in the form of major.minor e.g. 8.4
        if [ "${release:-none}" != "none" ]
        then
            rhel_release="$release"
        fi

	# Check if hostname is already in use
        if sudo virsh list --all | grep "${rhel_server_hostname}" > /dev/null 2>&1
        then
	    printf "%s\n" "  ${red:?}The name ${name} is already in use. Please try again with a different name${end:?}"
            exit 0
        fi

        # Get User Requested Instance size
        if [ "${size:-none}" == "small" ]
        then
            qubinode_vm_sizes_source="${project_dir}/samples/rhel_vms/small.yml"
        elif [ "${size:-none}" == "medium" ]
        then
            qubinode_vm_sizes_source="${project_dir}/samples/rhel_vms/medium.yml"
        elif [ "${size:-none}" == "large" ]
        then
            qubinode_vm_sizes_source="${project_dir}/samples/rhel_vms/large.yml"
        elif [ "${size:-none}" == "qubinode" ]
        then
            qubinode_vm_sizes_source="${project_dir}/samples/rhel_vms/qubinode.yml"
        elif [ "${size:-none}" == "satellite" ]
        then
            qubinode_vm_sizes_source="${project_dir}/samples/rhel_vms/satellite.yml"
        elif [ "${size:-none}" == "aap" ]
        then
            qubinode_vm_sizes_source="${project_dir}/samples/rhel_vms/aap.yml"
        else
            qubinode_vm_sizes_source="${project_dir}/samples/rhel_vms/small.yml"
        fi

	# Set up sizes for VM
        cat "${qubinode_vm_sizes_source}" >> "${rhel_vars_file}"

        ## Which RHEL release to deploy
        if [ "${release:-none}" == "7" ]
        then
            rhel_major=7
            qcow_image=$(grep "qcow_rhel${rhel_major}_name:" "${rhel_vars_file}"|awk '{print $2}')
        elif [ "${release:-none}" == "8" ]
        then
            rhel_major=8
            qcow_image=$(grep "qcow_rhel${rhel_major}_name:" "${rhel_vars_file}"|awk '{print $2}')
        else
            qcow_image=$(grep "qcow_rhel${rhel_major}_name:" "${rhel_vars_file}"|awk '{print $2}')
        fi

        ## Use static ip address if provided
        if [ "${ip:-none}" != "none" ]
        then
            sed -i "s/vm_ipaddress:.*/vm_ipaddress: "$ip"/g" "${rhel_vars_file}"
        fi

        ## Use netmask prefix if provided
        if [ "${cidr:-none}" != "none" ]
        then
            sed -i "s/vm_mask_prefix:.*/vm_mask_prefix: "$cidr"/g" "${rhel_vars_file}"
        elif [ "${ip:-none}" != "none" ]
        then
            sed -i "s/vm_mask_prefix:.*/vm_mask_prefix: "$KVM_HOST_MASK_PREFIX"/g" "${rhel_vars_file}"
        else
            sed -i "s/vm_mask_prefix:.*/vm_mask_prefix: '""'/g" "${rhel_vars_file}"
        fi   

        ## Use gateway if provided if provided
        if [ "${gw:-none}" != "none" ]
        then
            sed -i "s/vm_gateway:.*/vm_gateway:: "$gw"/g" "${rhel_vars_file}"
        elif [ "${ip:-none}" != "none" ]
        then
            sed -i "s/vm_gateway:.*/vm_gateway:: "$KVM_HOST_GTWAY"/g" "${rhel_vars_file}"
        else
            sed -i "s/vm_gateway:.*/vm_gateway:: '""'/g" "${rhel_vars_file}"
        fi

        ## Use mac address if provided
        if [ "${mac:-none}" != "none" ]
        then
            sed -i "s/vm_mac:.*/vm_mac: "$mac"/g" "${rhel_vars_file}"
        fi
    fi
}

function qubinode_rhel () {
    # Get all vm attributes
    qubinode_rhel_global_vars

    ## Ensure RHEL qcow image is available
    setup_download_options
}

function qubinode_generate_instance_id () {
    local name=$1
    while true
    do
      for i in $(seq -s " " -f %02g 100)
      do
        if ! sudo virsh list --all | grep "${name}${i}" >/dev/null 2>&1
        then
            instance_id="${i}"
            break
        fi
      done
      break
    done

}


function run_rhel_deployment () {

    ## This performs the actual deployment of RHEL and it's called by the funciton qubinode_deploy_rhel
    local rhel_server_hostname=$1
    sed -i "s/rhel_name:.*/rhel_name: "$rhel_server_hostname"/g" "${rhel_vars_file}"

    ## define the qcow disk image to use for the libvirt VM
    qcow_image_file="/var/lib/libvirt/images/${rhel_server_hostname}_vda.qcow2"

    #if ! sudo virsh list --all |grep -q "${rhel_server_hostname}"
    if ! sudo virsh dominfo "${rhel_server_hostname}" >/dev/null 2>&1
    then
        PLAYBOOK_STATUS=0
        sudo test -f $qcow_image_file && sudo rm -f $qcow_image_file 
        test -d ${project_dir}/.rhel || mkdir ${project_dir}/.rhel
        cp ${rhel_vars_file} "${project_dir}/.rhel/${rhel_server_hostname}-vars.yml"
	printf "%s\n" "  ${blu:?}Deploying a ${size} VM${end:?}"
        ansible-playbook "${RHEL_VM_PLAY}"
        PLAYBOOK_STATUS=$?
    fi

    # Run function to remove vm vars file
    delete_vm_vars_file
}

function delete_vm_vars_file () {
    # check if VM was deployed, if not delete the qcow image created for the vm
    VM_DELETED=no
    if ! sudo virsh list --all |grep -q "${rhel_server_hostname}"
    then
        sudo test -f $qcow_image_file && sudo rm -f $qcow_image_file
        rm -f "${project_dir}/.rhel/${rhel_server_hostname}-vars.yml"
	VM_DELETED=yes
    fi
}

function qubinode_deploy_rhel () {
    ## This is the primary function that iniatiates when qubinode-installer -p rhel is call.
    qubinode_rhel

    #os_release_num=$(awk -v var="rhel${rhel_release}_version" '$0 ~ var {print $2}' "${vars_file}")
    #os_release="rhel${os_release_num}"

    sed -i "s/qbn_rhel_name:.*/qbn_rhel_name: "$rhel_server_hostname"/g" "${rhel_vars_file}"
    sed -i "s/qbn_rhel_release:.*/qbn_rhel_rhel_release: "$rhel_release"/g" "${rhel_vars_file}"
    sed -i "s/qbn_rhel_major:.*/qbn_rhel_major: "$rhel_major"/g" "${rhel_vars_file}"

    if [ "${vcpu:-none}" != "none" ]
    then
        sed -i "s/qbn_rhel_vcpu:.*/qbn_rhel_vcpu: "$vcpu"/g" "${rhel_vars_file}"
    fi
    
    if [ "${memory:-none}" != "none" ]
    then
        sed -i "s/qbn_rhel_memory:.*/qbn_rhel_memory: "$memory"/g" "${rhel_vars_file}"
    fi
    
    
    if [ "${disk:-none}" != "none" ]
    then
        sed -i "s/qbn_rhel_root_disk_size:.*/qbn_rhel_root_disk_size: "$disk"/g" "${rhel_vars_file}"
    fi
    
    #sed -i "s/os_release:.*/os_release: "$os_release"/g" "${rhel_vars_file}"
    #sed -i "s/cloud_init_vm_image:.*/cloud_init_vm_image: "$qcow_image"/g" "${rhel_vars_file}"
    #sed -i "s/qcow_rhel_release:.*/qcow_rhel_release: "$rhel_release"/g" "${rhel_vars_file}"
    #sed -i "s/rhel_release:.*/rhel_release: "$rhel_release"/g" "${rhel_vars_file}"

    ## Check if user requested more than one VMs and deploy the requested count
    if [ "${qty:-none}" != "none" ]
    then
        re='^[0-9]+$'
        if ! [[ $qty =~ $re ]]
        then
           echo "error: The value for qty is not a integer." >&2; exit 1
        else
            for num in $(seq 1 $qty)
            do
                run_rhel_deployment "${rhel_server_hostname}${num}"
            done
        fi 
    else
        run_rhel_deployment "${rhel_server_hostname}"
    fi
}

function qubinode_rhel_teardown () {
    ## Run the qubinode_rhel_global_vars function to gather required variables
    qubinode_rhel_global_vars 

    if [ "${rhel_server_hostname:-none}" == "none" ]
    then
	printf "%s\n" "   Please specify the name of the instance to delete"
        printf "%s\n" "   Example: ./qubinode-install -p rhel -a name=qbn-rhel8-348 -d"
        exit 1
    fi

    PLAYBOOK="${project_dir}/.rhel/${name}-playbook.yml"
    VARS_FILE="${project_dir}/.rhel/${name}-vars.yml"

    if sudo virsh dominfo "${name}" >/dev/null 2>&1
    then
	printf "%s\n\n" ""
	confirm "${blu:?}This will remove $name, are you sure: y/n${end:?}"
	if [ "${response:-none}" == "yes" ]
        then
            if ansible-playbook "${RHEL_VM_PLAY}" --extra-vars "vm_teardown=true" -e @"${VARS_FILE}" || exit $?
	    then
		# ensure vm vars are deleted when the vm is deleted
	        delete_vm_vars_file
                if [ "${VM_DELETED:-none}" == "yes" ]
                then
                    printf "\n\n"
	            printf "%s\n" "  ${blu:?}Deleted VM ${name} ${end:?}"
                fi
	   else
	       printf "%s\n\n" "   ${red}There was a problem deleting the VM ${rhel_server_hostname} ${end}"
	       exit 1
	   fi
       fi
    else 
	printf "%s\n\n" "The VM $name does not exist"
    fi
}

function qubinode_rhel_vm_status () {
    VM_STATE=unknown

    if [ "${name:-none}" == "none" ]
    then
        local vm_names=$(sed -n '/\[rhel\]/,$p' inventory/hosts | grep -v '^\['|awk '{print $1}')
    else
        local vm_names="$name"
    fi

    if [ "${qubinode_maintenance_opt:-none}" == "status" ]
    then
        for name in $(echo "$vm_names")
        do
            if sudo virsh dominfo --domain $name >/dev/null 2>&1
            then
                VM_STATE=$(sudo virsh dominfo --domain $name | awk '/State:/ {print $2}')
                printf "%s\n" "VM $name current state is $VM_STATE"
            else
                printf "%s\n" "unknown ${qubinode_maintenance_opt}"
            fi
        done
    fi

    if [ "${qubinode_maintenance_opt:-none}" == "list" ]
    then
        for name in $(echo "$vm_names")
        do
            printf "%s\n" " Id    Name                           State"
            printf "%s\n" " --    ----                           -----"
            sudo virsh list --all| awk -v var="${name}" '$0 ~ var {printf "%s\n", $0}'
        done
    fi

}


function qubinode_rhel_maintenance () {
    ## Run the qubinode_rhel function to gather required variables
    qubinode_rhel_global_vars 

    VM_STATE=unknown

    qubinode_rhel_vm_status
    if [ "${name:-none}" != "none" ]
    then
        if sudo virsh dominfo --domain $name >/dev/null 2>&1
        then
            VM_STATE=$(sudo virsh dominfo --domain $name | awk '/State:/ {print $2}')
            WAIT_TIME=0

            # start up a vm
            if [[ "A${qubinode_maintenance_opt}" == "Astart" ]] && [[ "A${VM_STATE}" == "Ashut" ]]
            then
                printf "\n Starting up $name. \n"
                sudo virsh start $name >/dev/null 2>&1 && printf "%s\n" "$name started"

		## TODO: change this to a ansible ping to ensure VM is up and available
                until [[ $VM_STATE == "running" ]] || [[ $WAIT_TIME -eq 10 ]]
                do
                    VM_STATE=$(sudo virsh dominfo --domain $name | awk '/State/ {print $2}')
                    sleep $(( WAIT_TIME++ ))
                done

                if [ $VM_STATE == "running" ]
                then
                    printf "%s\n" "$name started"
                fi
            fi

            # shutdown a vm
            if [[ "A${qubinode_maintenance_opt}" == "Astop" ]] && [[ "A${VM_STATE}" == "Arunning" ]]
            then
                ansible $name -m command -a"shutdown +1 'Shutting down the VM'" -b >/dev/null 2>&1
                printf "\n Shutting down $name. \n"
                until [[ $VM_STATE != "running" ]] || [[ $WAIT_TIME -eq 10 ]]
                do
                    ansible $name -m command -a"shutdown +1 'Shutting down'" -b >/dev/null 2>&1
                    VM_STATE=$(sudo virsh dominfo --domain $name | awk '/State/ {print $2}')
                    sleep $(( WAIT_TIME++ ))
                done

                if [ $VM_STATE != "running" ]
                then
                    printf "%s\n" "$name stopped"
                fi

                if [ $VM_STATE == "running" ]
                then
                    sudo virsh destroy $name >/dev/null 2>&1 && printf "%s\n" "$name stopped"
                fi
            fi
        fi
    else
                printf "\n VM name is required. Example: \n"
                printf "\n ./qubinode-installer -p rhel -m ${qubinode_maintenance_opt} -a name=<vm_name>\n"
    fi

    printf "%s\n\n" ""
}
