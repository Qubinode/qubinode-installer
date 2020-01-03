#!/bin/bash

function check_hardware_resources () {
    if ! sudo virsh pool-list --details | grep -q "${libvirt_pool_name}"
    then
        echo "Libvirt Pool ${libvirt_pool_name} not found"
        echo "Please verify the variable libvirt_pool_name value is correct"
        exit 1
    fi

    PROJECTDIR=${project_dir}
    PERFORMANCE_MEMORY=131495372
    STANDARD_MEMORY=98304000
    SMALL_MEMORY=49152000
    MINIMAL_MEMORY=32768000

    MIN_STORAGE=488141
    RECOMMENDED_STORAGE=976282

    AVAILABLE_MEMORY=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    AVAILABLE_HUMAN_MEMORY=$(free -h | awk '/Mem/ {print $2}')

    AVAILABLE_STORAGE=$(sudo virsh pool-list --details | grep "${libvirt_pool_name}" |awk '{print $5*1024}')
    AVAILABLE_STORAGE_INT=${AVAILABLE_STORAGE%.*}
    AVAILABLE_HUMAN_STORAGE=$(sudo virsh pool-list --details | grep "${libvirt_pool_name}" |awk '{print $5,$6}')

    # Check for available storage
    if sudo virsh pool-list --details | grep -q "${libvirt_pool_name}"
    then
        if [[ ${AVAILABLE_STORAGE_INT} -ge ${RECOMMENDED_STORAGE} ]]
        then
            echo "Your available storage of ${AVAILABLE_HUMAN_STORAGE} meets the requirements."
        elif [[ ${AVAILABLE_STORAGE_INT} -ge ${MIN_STORAGE} ]]
        then
             echo "Your available storage of ${AVAILABLE_HUMAN_STORAGE} does not meet our recommend minimum of 1TB."
             echo "The installation will continue, but you may run out of storage depending on your workload."
        else
            echo "Your available storage of ${AVAILABLE_HUMAN_STORAGE} does not meet the requirements."
            read -p "Do you want to continue with a minimal installation? y/n " -n 1 -r
            echo "REPLY is $REPLY"
            if [[ ! $REPLY =~ ^[Nn]$ ]]
            then
                echo "Your available storage of ${AVAILABLE_HUMAN_STORAGE} does not meet our recommend minimum of 1TB."
                echo "The installation will continue, but you may run out of storage depending on your workload."
            else
                echo "Aborting installation, the minium supported storage is $MIN_STORAGE"
                exit 1
            fi
        fi
    else
        echo "Could not find the qubinode libvirt pool **${libvirt_pool_name}**"
        echo "No storage check was performed, please ensure your pool has enough storage"
    fi

    
    echo "${AVAILABLE_MEMORY} -ge ${SMALL_MEMORY}"
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
        echo "Your available memory of ${AVAILABLE_HUMAN_MEMORY} is not enough to continue"
        read -p "Do you want to continue with a minimal instalation? y/n " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]
        then
            memory_size=minimal
            echo "Your available memory ${AVAILABLE_HUMAN_MEMORY} does not meet our minimum supported."
            echo "The installation will continue, but you may run out of memory depending on your workload"
            bash ${project_dir}/lib/qubinode_openshift_sizing_menu.sh $memory_size
        else
            echo "Aborting installation, the minium supported memory is ${MINIMAL_MEMORY}"
            exit $?
        fi
    fi 
}
