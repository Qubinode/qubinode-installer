function check_hardware_resources () {
    PROJECTDIR=${1}
    STANDARD_MEMORY=131495372
    SMALL_MEMORY=976282
    MINIMAL_MEMORY=488141

    MIN_STORAGE=488141
    RECOMMENDED_STORAGE=976282

    AVAILABLE_MEMORY=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    AVAILABLE_HUMAN_MEMORY=$(free -h | awk '/Mem/ {print $2}')

    AVAILABLE_STORAGE=$(sudo virsh pool-list --details | awk '/images/ {print $5*1024}')
    AVAILABLE_HUMAN_STORAGE=$(sudo virsh pool-list --details | awk '/images/ {print $5,$6}')

    # Check for available storage
    if sudo virsh pool-list --details | grep images
    then
        if [[ ${AVAILABLE_STORAGE} -ge ${RECOMMENDED_STORAGE} ]]
        then
          echo "Your available storage of ${AVAILABLE_HUMAN_STORAGE} meets the requirements."
        elif [[ ${AVAILABLE_STORAGE} -ge ${MIN_STORAGE} ]]
        then
          echo "Your available storage of ${AVAILABLE_HUMAN_STORAGE} does not meet our recommend minimum of 1TB."
          echo "The installation will continue, but you may run out of storage depending on your workload."
        else
          echo "Your available storage of ${AVAILABLE_HUMAN_STORAGE} does not meet the requirements."
          exit $?
        fi
    else
        echo "Could not find the qubinode libvirt pool **images**"
        echo "No storage check was performed, please ensure your pool has enough storage"
    fi

    # Set OpenShift deployment size based on available memory
    if [[ ${AVAILABLE_MEMORY} -ge ${STANDARD_MEMORY} ]]
    then
        echo "Do standard OpenShift Deployment"
        #cat ${PROJECTDIR}/samples/ocp_vm_sizing/standard.yml >> ${PROJECTDIR}/playbooks/vars/all.yml
        lib/qubinode_openshift_sizing_menu.sh standard
    elif [[ ${AVAILABLE_MEMORY} -ge ${SMALL_MEMORY} ]]
    then
        echo "Do minimal OpenShift Deployment" minimal_cns
        #cat ${PROJECTDIR}/samples/ocp_vm_sizing/small.yml >> ${PROJECTDIR}/playbooks/vars/all.yml
        lib/qubinode_openshift_sizing_menu.sh
    elif [[ ${AVAILABLE_MEMORY} -ge ${MINIMAL_MEMORY} ]]
    then
        echo "Do minimal OpenShift Deployment" minimal
        #cat ${PROJECTDIR}/samples/ocp_vm_sizing/minimal.yml >> ${PROJECTDIR}/playbooks/vars/all.yml
        lib/qubinode_openshift_sizing_menu.sh
    else
        echo "Your available memory of ${AVAILABLE_HUMAN_MEMORY} is not enough to continue"
        exit $?
    fi

    exit 0
}
