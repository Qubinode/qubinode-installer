#!/bin/bash

function check_hardware_resources () {
    validate_hardware_resources
    select_openshift3_cluster_size
}

function validate_hardware_resources () {
    if ! sudo virsh pool-list --details | grep -q "${libvirt_pool_name}"
    then
        printf "%s\n" " Libvirt Pool ${libvirt_pool_name} not found"
        printf "%s\n" " Please verify the variable libvirt_pool_name value is correct"
        exit 1
    fi

    PROJECTDIR=${project_dir}

    # MEMORY
    PERFORMANCE_MEMORY=$(awk '/openshift3_performance_memory:/ {print $2}' "${ocp3_vars_file}")
    STANDARD_MEMORY=$(awk '/openshift3_standard_memory:/ {print $2}' "${ocp3_vars_file}")
    SMALL_MEMORY=$(awk '/openshift3_small_memory:/ {print $2}' "${ocp3_vars_file}")
    MINIMAL_MEMORY=$(awk '/openshift3_minimal_memory:/ {print $2}' "${ocp3_vars_file}")
    AVAILABLE_MEMORY=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    AVAILABLE_HUMAN_MEMORY=$(free -h | awk '/Mem/ {print $2}')

    # STORAGE
    MIN_STORAGE=$(awk '/openshift3_minimal_storage:/ {print $2}' "${ocp3_vars_file}")
    RECOMMENDED_STORAGE=$(awk '/openshift3_recommended_storage:/ {print $2}' "${ocp3_vars_file}")
    AVAILABLE_STORAGE=$(sudo virsh pool-list --details | grep "${libvirt_pool_name}" |awk '{print $5*1024}')
    AVAILABLE_STORAGE_INT=${AVAILABLE_STORAGE%.*}
    AVAILABLE_HUMAN_STORAGE=$(sudo virsh pool-list --details | grep "${libvirt_pool_name}" |awk '{print $5,$6}')

    # Check for available storage
    if sudo virsh pool-list --details | grep -q "${libvirt_pool_name}"
    then
        if [[ ${AVAILABLE_STORAGE_INT} -ge ${RECOMMENDED_STORAGE} ]]
        then
            printf "%s\n" "Your available storage of ${AVAILABLE_HUMAN_STORAGE} meets the requirements."
        elif [[ ${AVAILABLE_STORAGE_INT} -ge ${MIN_STORAGE} ]]
        then
             printf "%s\n" "Your available storage of ${AVAILABLE_HUMAN_STORAGE} does not meet our recommend minimum of 1TB."
             printf "%s\n" "The installation will continue, but you may run out of storage depending on your workload."
        else
            printf "%s\n" "Your available storage of ${AVAILABLE_HUMAN_STORAGE} does not meet the requirements."
            read -p "Do you want to continue with a minimal installation? y/n " -n 1 -r
            echo "REPLY is $REPLY"
            if [[ ! $REPLY =~ ^[Nn]$ ]]
            then
                printf "%s\n" "Your available storage of ${AVAILABLE_HUMAN_STORAGE} does not meet our recommend minimum of 1TB."
                printf "%s\n" "The installation will continue, but you may run out of storage depending on your workload."
            else
                printf "%s\n" "Aborting installation, the minium supported storage is $MIN_STORAGE"
                exit 1
            fi
        fi
    else
        printf "%s\n" "Could not find the qubinode libvirt pool **${libvirt_pool_name}**"
        printf "%s\n" "No storage check was performed, please ensure your pool has enough storage"
    fi
}
    
function select_openshift3_cluster_size () {
    printf "%s\n" "${AVAILABLE_MEMORY} -ge ${SMALL_MEMORY}"
    # Set OpenShift deployment size based on available memory
    if [[ ${AVAILABLE_MEMORY} -ge ${STANDARD_MEMORY} ]]
    then
        memory_size=standard
        bash ${project_dir}/lib/qubinode_openshift_sizing_menu.sh $memory_size
    elif [[ ${AVAILABLE_MEMORY} -ge ${SMALL_MEMORY} ]]
    then
        memory_size=small
        bash ${project_dir}/lib/qubinode_openshift_sizing_menu.sh $memory_size
    elif [[ ${AVAILABLE_MEMORY} -ge ${MINIMAL_MEMORY} ]]
    then
        memory_size=minimal
        bash ${project_dir}/lib/qubinode_openshift_sizing_menu.sh $memory_size
    else
        printf "%s\n" "Your available memory of ${AVAILABLE_HUMAN_MEMORY} is not enough to continue"
        read -p "Do you want to continue with a minimal instalation? y/n " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]
        then
            memory_size=minimal
            printf "%s\n" "Your available memory ${AVAILABLE_HUMAN_MEMORY} does not meet our minimum supported."
            printf "%s\n" "The installation will continue, but you may run out of memory depending on your workload"
            bash ${project_dir}/lib/qubinode_openshift_sizing_menu.sh $memory_size
        else
            printf "%s\n" "Aborting installation, the minium supported memory is ${MINIMAL_MEMORY}"
            exit $?
        fi
    fi 
}
