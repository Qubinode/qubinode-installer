#!/bin/bash


function qubinode_autoinstall_openshift () {
    product_in_use="ocp3" # Tell the installer this is openshift3 installation
    openshift_product="${product_in_use}"
    qubinode_product_opt="${product_in_use}"
    openshift_auto_install=true # Tells the installer to use defaults options
    update_variable=true

    printf "\n\n ${yel}*************************${end}\n"
    printf " ${yel}*${end} ${cyn}Deploying OpenShift 3${end}${yel} *${end}\n"
    printf " ${yel}*************************${end}\n\n"

    # Ensure configuration files from samples/ are copied to playbooks/vars/
    qubinode_required_prereqs

    # Ensure the RHEL qcow image exists
    pre_check_for_rhel_qcow_image

    # Check if this will be a qubinode install
    ask_user_if_qubinode_setup

    # Check if the device meets the minimum storage and memory requirement
    # and set the storage_profile and memory requirement value
    storage_profile=$(awk '/^storage_profile:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
    memory_profile=$(awk '/^memory_profile:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")

    if [[ "A${memory_profile}" == 'A""' ]] && [[ "A${storage_profile}" == 'A""' ]]
    then
        check_additional_storage
        check_hardware_resources
    fi

    # Check your hardware resources and determine the size of your openshift
    # cluster deployment
    check_openshift3_size_yml

    #TODO: HERE
    # - ensure the user isn't prompted for information they have already provided
    # - validate how things work up to this point if user choose not to do a qubinode install

    # Add current user to sudoers, setup global variables, run additional
    # prereqs, setup current user ssh key, ask user if they want to
    # deploy a qubinode system.
    qubinode_installer_setup

    # Ensure global variables are setup, system registered to Red Hat,
    # and ansible is installed.
    qubinode_base_requirements

    # Check OpenShift deployment size and change if it needs to be

    # Check current deployment size
    current_deployment_size=$(awk '/openshift_deployment_size:/ {print $2}' "${ocp3_vars_file}")
    # The default openshift size is stanadard
    # This ensures that if the size is already set
    # it does not get overwritten
    if [ "A${current_deployment_size}" == 'A""' ]
    then
        #echo "Setting Openshift deployment size to standard."
        sed -i "s/openshift_deployment_size:.*/openshift_deployment_size: standard/g" "${ocp3_vars_file}"
    fi


    printf "\n\n***************************\n"
    printf "* Running qubinode perquisites *\n"
    printf "******************************\n\n"
    qubinode_installer_setup

    printf "\n\n********************************************\n"
    printf "* Ensure host system is registered to RHSM *\n"
    printf "*********************************************\n\n"
    qubinode_rhsm_register

    printf "\n\n*******************************************************\n"
    printf "* Ensure host system is setup as a ansible controller *\n"
    printf "*******************************************************\n\n"
    test ! -f /usr/bin/ansible && qubinode_setup_ansible

    printf "\n\n*********************************************\n"
    printf     "* Ensure host system is setup as a KVM host *\n"
    printf     "*********************************************\n"
    ping_nodes
    if [ "A${PINGED_NODES_TOTAL}" != "A${TOTAL_NODES}" ]
    then
        qubinode_setup_kvm_host
    fi
    printf "\n\n****************************\n"
    printf     "* Deploy IdM DNS Server    *\n"
    printf     "****************************\n"
    qubinode_deploy_idm

    printf "\n\n*********************\n"
    printf     "*Deploy ${product_in_use} cluster *\n"
    printf     "*********************\n"
    sed -i "s/openshift_product:.*/openshift_product: $openshift_product/g" "${ocp3_vars_file}"
    sed -i "s/openshift_auto_install:.*/openshift_auto_install: "$openshift_auto_install"/g" "${ocp3_vars_file}"
    openshift_enterprise_deployment
    openshift3_installation_msg
}
