#!/bin/bash


function qubinode_installer_setup () {

    # Ensure configuration files from samples/ are copied to playbooks/vars/
    qubinode_required_prereqs

    # Ensure user is setup for sudoers
    setup_sudoers

    check_additional_storage
    #ask_user_if_qubinode_setup

    # load kvmhost variables
    kvm_host_variables

    if [ "A${product_in_use}" == "Aocp3" ]
    then
        # Set the QUBINODE_SYSTEM variable based on user response
        QUBINODE_SYSTEM=$(awk '/run_qubinode_setup:/ {print $2; exit}' "${vars_file}" | tr -d '"')
        # Check if the device meets the minimum storage and memory requirement
        # and set the storage_profile and memory requirement value
        storage_profile=$(awk '/^storage_profile:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
        memory_profile=$(awk '/^memory_profile:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")

        if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
        then
            if [[ "A${memory_profile}" == 'A""' ]] && [[ "A${storage_profile}" == 'A""' ]]
            then
                check_additional_storage
                check_hardware_resources
            fi
        else
            if [[ "A${memory_profile}" == 'A""' ]] && [[ "A${storage_profile}" == 'A""' ]]
            then
                check_libvirt_pool
                check_libvirt_network
                check_hardware_resources
            fi
        fi
    
        # Check your hardware resources and determine the size of your openshift
        # cluster deployment
        # TODO: add option to check if openshift is already deployed then choose
        #skip this step if it.
        check_openshift3_size_yml
    fi

    # Start user input session
    ask_user_input
    setup_variables
    setup_user_ssh_key
    #ask_user_for_networking_info "${vars_file}"

    # Ensure ./qubinode-installer -m rhsm is completed
    if [ "A${rhsm_completed}" == "Ano" ]
    then
       qubinode_rhsm_register
    fi

    # Ensure ./qubinode-installer -m ansible is completed
    if [ "A${ansible_completed}" == "Ano" ]
    then
       qubinode_setup_ansible
    fi

    # Ensure RHSM cli is installed
    install_rhsm_cli

    sed -i "s/qubinode_base_reqs_completed:.*/qubinode_base_reqs_completed: yes/g" "${vars_file}"
    sed -i "s/qubinode_installer_setup_completed:.*/qubinode_installer_setup_completed: yes/g" "${vars_file}"

    #printf "\n\n${yel}    ***************************${end}\n"
    #printf "${yel}    *   Setup is complete   *${end}\n"
    #printf "${yel}    ***************************${end}\n\n"
}
