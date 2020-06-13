#!/bin/bash
function qubinode_rhel () {
    setup_variables
    RHEL_VM_PLAY="${project_dir}/playbooks/rhel.yml"
    rhel_vars_file="${project_dir}/playbooks/vars/rhel.yml"


    product_in_use=rhel
    prefix=$(awk '/instance_prefix/ {print $2;exit}' "${vars_file}")
    suffix=rhel

    # Generate a random id that's not already is use for the cattle vms
    while true
    do
        instance_id=$((1 + RANDOM % 4096))
        if ! sudo virsh list --all | grep $instance_id
        then
            break
        fi
    done

    # Check for user provided variables
    for var in "${product_options[@]}"
    do
       export $var
    done

    if [ "A${release}" != "A" ]
    then
        rhel_release="$release"
    else
        rhel_release=7
    fi

    if [ "A${name}" != "A" ]
    then
        rhel_server_hostname="${prefix}-${suffix}${rhel_release}-${name}"
    else
        rhel_server_hostname="${prefix}-${suffix}${rhel_release}-${instance_id}"
    fi

    # Get instance size
    vcpu=1
    memory=800
    disk=20G
    # Get instance size
    if [ "A${size}" != "A" ]
    then
        if [ "A${size}" == "Asmall" ]
        then
            vcpu=1
            memory=800
            disk=10G
            expand_os_disk=no
        elif [ "A${size}" == "Amedium" ]
        then
            vcpu=2
            memory=2048
            disk=60G
            expand_os_disk=yes
        elif [ "A${size}" == "Alarge" ]
        then
            vcpu=4
            memory=8192
            disk=120G
            expand_os_disk=yes
        else
            echo "using default size"
       fi
    fi

    # Default RHEL release to deploy
    if [ "A${release}" == "A7" ]
    then
        rhel_major=7
        qcow_image=$(grep "qcow_rhel${rhel_major}_name:" "${project_dir}/playbooks/vars/all.yml"|awk '{print $2}')
    elif [ "A${release}" == "A8" ]
    then
        rhel_major=8
        qcow_image=$(grep "qcow_rhel${rhel_major}_name:" "${project_dir}/playbooks/vars/all.yml"|awk '{print $2}')
    else
        rhel_major=7
        qcow_image=$(grep "qcow_rhel${rhel_major}_name:" "${project_dir}/playbooks/vars/all.yml"|awk '{print $2}')
    fi

    rhel_server_fqdn="${rhel_server_hostname}.${domain}"

    # Ensure rhel vars file is active
    if [ ! -f "${rhel_vars_file}" ]
    then
        cp "${project_dir}/samples/rhel.yml" "${rhel_vars_file}"
    fi

    # Ensure RHEL qcow image is available
    setup_download_options
    install_rhsm_cli
    download_files
}

function qubinode_deploy_rhel () {
    qubinode_rhel
    sed -i "s/rhel_name:.*/rhel_name: "$rhel_server_hostname"/g" "${rhel_vars_file}"
    sed -i "s/rhel_vcpu:.*/rhel_vcpu: "$vcpu"/g" "${rhel_vars_file}"
    sed -i "s/rhel_memory:.*/rhel_memory: "$memory"/g" "${rhel_vars_file}"
    sed -i "s/rhel_root_disk_size:.*/rhel_root_disk_size: "$disk"/g" "${rhel_vars_file}"
    sed -i "s/cloud_init_vm_image:.*/cloud_init_vm_image: "$qcow_image"/g" "${rhel_vars_file}"
    sed -i "s/qcow_rhel_release:.*/qcow_rhel_release: "$rhel_release"/g" "${rhel_vars_file}"
    sed -i "s/rhel_release:.*/rhel_release: "$rhel_release"/g" "${rhel_vars_file}"
    sed -i "s/expand_os_disk:.*/expand_os_disk: "$expand_os_disk"/g" "${rhel_vars_file}"


    # Ensure the RHEL qcow image is at /var/lib/libvirt/images
    RHEL_QCOW_SOURCE="/var/lib/libvirt/images/${qcow_image_file}"
    if [ ! -f "{RHEL_QCOW_SOURCE}" ]
    then
        if [ -f "${project_dir}/${qcow_image}" ]
        then
             sudo cp "${project_dir}/${qcow_image}" "${RHEL_QCOW_SOURCE}" 
        else
            echo "Please download ${qcow_image} to ${RHEL_QCOW_SOURCE}"
            exit 1
        fi
    fi

    if [ "A${qty}" != "A" ]
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

function run_rhel_deployment () {
    local rhel_server_hostname=$1
    sed -i "s/rhel_name:.*/rhel_name: "$rhel_server_hostname"/g" "${rhel_vars_file}"
    qubinode_networking
    qcow_image_file="/var/lib/libvirt/images/${rhel_server_hostname}_vda.qcow2"
    #if ! sudo virsh list --all |grep -q "${rhel_server_hostname}"
    if ! sudo virsh dominfo "${rhel_server_hostname}" >/dev/null 2>&1
    then
        PLAYBOOK_STATUS=0
        sudo test -f $qcow_image_file && sudo rm -f $qcow_image_file 
        test -d ${project_dir}/.rhel || mkdir ${project_dir}/.rhel
        cp ${rhel_vars_file} "${project_dir}/.rhel/${rhel_server_hostname}-vars.yml"
        echo "Deploying $rhel_server_hostname"
        ansible-playbook "${RHEL_VM_PLAY}"
        PLAYBOOK_STATUS=$?
    fi

    # check if VM was deployed, if not delete the qcow image created for the vm
    if ! sudo virsh list --all |grep -q "${rhel_server_hostname}"
    then
        sudo test -f $qcow_image_file && sudo rm -f $qcow_image_file
        rm -f "${project_dir}/.rhel/${rhel_server_hostname}-vars.yml"
    fi

    # return the status of the playbook run
    #return $PLAYBOOK_STATUS
}


function qubinode_rhel_teardown () {
    qubinode_rhel
    if [ "A${name}" == "A" ]
    then
        echo "Please specify the name of the instance to delete"
        echo "Example: ./qubinode-install -p rhel -a name=qbn-rhel8-348 -d"
        exit
    fi

    PLAYBOOK="${project_dir}/.rhel/${name}-playbook.yml"
    VARS_FILE="${project_dir}/.rhel/${name}-vars.yml"

    if sudo virsh dominfo "${name}" >/dev/null 2>&1
    then
        echo "removing $name"
        ansible-playbook "${RHEL_VM_PLAY}" --extra-vars "vm_teardown=true" -e @"${VARS_FILE}"
        RESULT=$?

        if [ $RESULT -eq 0 ]
        then
            rm -f "${project_dir}/.rhel/${rhel_server_hostname}-vars.yml"
            printf "\n\n*************************\n"
            printf "  * VM $name deleted *\n"
            printf "*************************\n\n"
        fi
    else 
        echo "The VM $name does not exist"
    fi
}

function qubinode_rhel_maintenance () {
    qubinode_rhel
    VM_STATE=unknown

    if sudo virsh dominfo --domain $name >/dev/null 2>&1
    then
        VM_STATE=$(sudo virsh dominfo --domain $name | awk '/State:/ {print $2$3}')
        WAIT_TIME=0

        # start up a vm
        if [[ "A${qubinode_maintenance_opt}" == "Astart" ]] && [[ "A${VM_STATE}" == "Ashutoff" ]]
        then
            sudo virsh start $name >/dev/null 2>&1 && printf "%s\n" "$name started"
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

        # vm status
        if [ "A${qubinode_maintenance_opt}" == "Astatus" ]
        then
            printf "%s\n" "VM current state is $VM_STATE"
        fi
    fi

    # show VM status
    if [ "A${qubinode_maintenance_opt}" == "Alist" ]
    then
        printf "%s\n" " Id    Name                           State"
        printf "%s\n" " --    ----                           -----"
        sudo virsh list| awk '/rhel/ {printf "%s\n", $0}'
    else
        printf "%s\n" "unknown ${qubinode_maintenance_opt}"
    fi

    printf "%s\n\n" ""
}
