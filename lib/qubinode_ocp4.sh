#!/bin/bash

function setup_required_paths () {
    current_dir="`dirname \"$0\"`"
    project_dir="$(dirname ${current_dir})"
    project_dir="`( cd \"$project_dir\" && pwd )`"
    if [ -z "$project_dir" ] ; then
        config_err_msg; exit 1
    fi

    if [ ! -d "${project_dir}/playbooks/vars" ] ; then
        config_err_msg; exit 1
    fi
    DEPLOY_OCP4_PLAYBOOK="${project_dir}/playbooks/deploy_ocp4.yml"
}

check_if_cluster_deployed () {
    if [[ -f /usr/local/bin/qubinode-ocp4-status ]] && [[ -f /usr/local/bin/oc ]]\
       && [[ -f $HOME/.kube/config ]] || [[ -d ${project_dir}/ocp4/auth ]]
    then
        NODES=$(/usr/local/bin/oc get nodes 2>&1| grep -i master)
        if [ "A${NODES}" != "A" ]
        then
            ansible-playbook "${DEPLOY_OCP4_PLAYBOOK}" -e '{ check_existing_cluster: False }' -e '{ deploy_cluster: False }' -e '{ cluster_deployed_msg: "deployed" }' -t bootstrap_shut > /dev/null 2>&1 || exit $?
            printf "%s\n\n" " ${grn}OpenShift Cluster is already deployed${end}"
            /usr/local/bin/qubinode-ocp4-status
            # Configure Advanced options 
            advanced_ocp4_options
            exit 0
        fi
    fi
}

function advanced_ocp4_options(){
    # -a flags for storage and other openshift modfications
    # Check for user provided variables
    for var in "${product_options[@]}"
    do
       export $var
    done


    #local storage options 
    if [ "A${storage}" != "A" ]
    then
        if [ "$storage" == "nfs" ]
        then
          echo "You are going to reconfigure ${storage}"
          ansible-playbook  "${DEPLOY_OCP4_PLAYBOOK}"  -t nfs --extra-vars "configure_nfs_storage=true" --extra-vars "cluster_deployed_msg=deployed"
        elif [ "$storage" == "nfs-remove" ]
        then 
          echo "You are going to Remove ${storage}  from the openshift cluster"
          ansible-playbook  "${DEPLOY_OCP4_PLAYBOOK}"  -t nfs --extra-vars "configure_nfs_storage=true" --extra-vars "cluster_deployed_msg=deployed" --extra-vars "delete_deployment=true" --extra-vars "gather_facts=true" 
        fi

        # localstorage option 
        if [ "$storage" == "localstorage" ]
        then
          echo "You are going to reconfigure ${storage}"
          ansible-playbook  "${DEPLOY_OCP4_PLAYBOOK}"  -t localstorage --extra-vars "configure_local_storag=true" --extra-vars "cluster_deployed_msg=deployed"
        elif [ "$storage" == "localstorage-remove" ]
        then 
          echo "You are going to Remove ${storage}  from the openshift cluster"
          ansible-playbook  "${DEPLOY_OCP4_PLAYBOOK}"  -t localstorage --extra-vars "configure_local_storag=true" --extra-vars "cluster_deployed_msg=deployed" --extra-vars "delete_deployment=true" --extra-vars "gather_facts=true"
        fi
    fi
}

function qubinode_deploy_ocp4 () {
    product_in_use="ocp4" # Tell the installer which release of OCP
    openshift_product="${product_in_use}"
    qubinode_product_opt="${product_in_use}"

    # Ensure project paths are setup correctly
    setup_required_paths
    [[ -f ${project_dir}/lib/qubinode_kvmhost.sh ]] && . ${project_dir}/lib/qubinode_kvmhost.sh || exit 1
    [[ -f ${project_dir}/lib/qubinode_ocp4_utils.sh ]] && . ${project_dir}/lib/qubinode_ocp4_utils.sh || exit 1

    # Check if openshift cluster is already deployed and running
    check_if_cluster_deployed

    # load required files from samples to playbooks/vars/
    qubinode_required_prereqs

    # Add current user to sudoers, setup global variables, run additional
    # prereqs, setup current user ssh key, ask user if they want to
    # deploy a qubinode system.
    qubinode_installer_setup

    # Ensure the KVM host is setup
    # System is attached to the OpenShift subscription
    # Get the version number for the lastest openshift
    openshift4_prechecks

    # Ensure host system is setup as a KVM host
    if [[ "A${KVM_IN_GOOD_HEALTH}" != "Aready"  ]]; then
        qubinode_setup_kvm_host
    fi

    # Ensure the system meets the requirement for a standard OCP deployment
    check_openshift4_size_yml

    # make sure no old VMs from previous deployments are still around
    state_check

    # Deploy IdM Server
    openshift4_idm_health_check
    if [[  "A${IDM_IN_GOOD_HEALTH}" != "Aready"  ]]; then
      
        # Download rhel qcow image if rhsm token provided
        download_files
      
        # Deploy IdM
        qubinode_deploy_idm
    fi

    # Deploy OCP4
    ansible-playbook "${DEPLOY_OCP4_PLAYBOOK}" -e '{ check_existing_cluster: False }'  -e '{ deploy_cluster: True }' || exit $?

    # Check the OpenSHift status
    check_if_cluster_deployed
}

function openshift4_qubinode_teardown () {
    confirm " Are you sure you want to delete the OpenShift 4 cluster? yes/no"
    if [ "A${response}" == "Ayes" ]
    then
        DEPLOY_OCP4_PLAYBOOK="${project_dir}/playbooks/deploy_ocp4.yml"
        ansible-playbook "${DEPLOY_OCP4_PLAYBOOK}" -e '{ tear_down: True }' || exit $?
        test -f "${project_dir}/playbooks/vars/ocp4.yml" && rm -f "${project_dir}/playbooks/vars/ocp4.yml"
        printf "%s\n\n\n\n" " ${grn}OpenShift Cluster destroyed!${end}"
        
    else
        exit 0
    fi
}
