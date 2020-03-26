#!/bin/bash

function check_disk_size () {
    # STORAGE
    MIN_STORAGE=$(awk '/qubinode_minimal_storage:/ {print $2}' "${vars_file}")
    STANDARD_STORAGE=$(awk '/qubinode_standard_storage:/ {print $2}' "${vars_file}")
    PERFORMANCE_STORAGE=$(awk '/qubinode_performance_storage:/ {print $2}' "${vars_file}")
    MIN_STORAGE=${MIN_STORAGE:-370}
    STANDARD_STORAGE=${STANDARD_STORAGE:-900}
    PERFORMANCE_STORAGE=${PERFORMANCE_STORAGE:-1000}

    if rpm -qf /bin/lsblk > /dev/null 2>&1
    then
        # If not setting system as a Qubinode then the
        # variable POOL_CAPACITY should be defined. Use it to
        # determine if there is enough storage to continue
        if [ "A${POOL_CAPACITY}" != "A" ]
        then
            convertB_human $POOL_CAPACITY
        else
            DISK_INFO=$(lsblk -dpb | grep $DISK)
            CURRENT_DISK_SIZE=$(echo $DISK_INFO| awk '{print $4}')
            convertB_human $CURRENT_DISK_SIZE
        fi

        # Set the system storage profile based on disk or libvirt pool capacity
        if [[ $DISK_SIZE_COMPARE -ge $MIN_STORAGE ]] && [[ $DISK_SIZE_COMPARE -lt $STANDARD_STORAGE ]]
        then
            printf "%s\n" " The storage size $DISK_SIZE_HUMAN meets the minimum storage requirement of $MIN_STORAGE GB"
            STORAGE_PROFILE=minimal
        elif [[ $DISK_SIZE_COMPARE -ge $STANDARD_STORAGE ]] && [[ $DISK_SIZE_COMPARE -lt $PERFORMANCE_STORAGE ]]
        then
            printf "%s\n" " The storage size $DISK_SIZE_HUMAN meets the standard storage requirement of $STANDARD_STORAGE GB"
            STORAGE_PROFILE=standard
        elif [[ $DISK_SIZE_COMPARE -ge $PERFORMANCE_STORAGE ]]
        then
            printf "%s\n" " The storage size $DISK_SIZE_HUMAN meets the performance storage requirement of $PERFORMANCE_STORAGE GB"
            STORAGE_PROFILE=performance
        else
           printf "%s\n" " The storage size $DISK_SIZE_HUMAN does not meet the minimum size of the $MIN_STORAGE GB"
            STORAGE_PROFILE=notmet
        fi
    else
        printf "%s\n" " The utility /bin/lsblk is missing. Please install the util-linux package."
        exit 1
    fi
}

function check_memory_size () {
    
    MINIMAL_MEMORY=$(awk '/qubinode_minimal_memory:/ {print $2}' "${vars_file}")
    STANDARD_MEMORY=$(awk '/qubinode_standard_memory:/ {print $2}' "${vars_file}")
    PERFORMANCE_MEMORY=$(awk '/qubinode_performance_memory:/ {print $2}' "${vars_file}")
    
    MINIMAL_MEMORY=${MINIMAL_MEMORY:-30}
    STANDARD_MEMORY=${STANDARD_MEMORY:-80}
    PERFORMANCE_MEMORY=${PERFORMANCE_MEMORY:-88}

    TOTAL_MEMORY=$(free -g|awk '/^Mem:/{print $2}')
    
    if [[ $TOTAL_MEMORY -ge $MINIMAL_MEMORY ]] && [[ $TOTAL_MEMORY -lt $STANDARD_MEMORY ]]
    then
        printf "%s\n" " The memory size $TOTAL_MEMORY GB meets the minimum memory requirement of $MINIMAL_MEMORY GB"
        MEMORY_PROFILE=minimal
    elif [[ $TOTAL_MEMORY -ge $STANDARD_MEMORY ]] && [[ $TOTAL_MEMORY -lt $PERFORMANCE_MEMORY ]]
    then
        printf "%s\n" " The memory size $TOTAL_MEMORY GB meets the standard memory requirement of $STANDARD_MEMORY GB"
        MEMORY_PROFILE=standard
    elif [[ $TOTAL_MEMORY -ge $PERFORMANCE_MEMORY ]]
    then
        printf "%s\n" " The memory size $TOTAL_MEMORY GB meets the performance memory requirement of $PERFORMANCE_MEMORY GB"
        MEMORY_PROFILE=performance
    else
       printf "%s\n" " The memory size $TOTAL_MEMORY GB does not meet the minimum size of the $MINIMAL_MEMORY GB"
       MEMORY_PROFILE=notmet
    fi
}

function check_hardware_resources () {
    check_disk_size
    check_memory_size

    if [[ "$STORAGE_PROFILE" != "$MEMORY_PROFILE" ]] && [[ "$STORAGE_PROFILE" != minimal ]] && [[ "$MEMORY_PROFILE" != minimal ]]
    then
        local PROFILE=standard
        sed -i "s/storage_profile:.*/storage_profile: "$PROFILE"/g" "${vars_file}"
        sed -i "s/memory_profile:.*/memory_profile: "$PROFILE"/g" "${vars_file}"
    elif [[ "$STORAGE_PROFILE" != "$MEMORY_PROFILE" ]] && [[ "$STORAGE_PROFILE" == minimal ]] || [[ "$MEMORY_PROFILE" == minimal ]]
    then
        local PROFILE=minimal
        sed -i "s/storage_profile:.*/storage_profile: "$PROFILE"/g" "${vars_file}"
        sed -i "s/memory_profile:.*/memory_profile: "$PROFILE"/g" "${vars_file}"
    else
        sed -i "s/storage_profile:.*/storage_profile: "$STORAGE_PROFILE"/g" "${vars_file}"
        sed -i "s/memory_profile:.*/memory_profile: "$MEMORY_PROFILE"/g" "${vars_file}"
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
