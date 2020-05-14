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
            exit 0
        fi
    fi
}


function qubinode_autoinstall_openshift4 () {
    product_in_use="ocp4" # Tell the installer which release of OCP
    openshift_product="${product_in_use}"
    qubinode_product_opt="${product_in_use}"

    # Ensure project paths are setup correctly
    setup_required_paths
    [[ -f ${project_dir}/lib/qubinode_kvmhost.sh ]] && . ${project_dir}/lib/qubinode_kvmhost.sh || exit 1
    [[ -f ${project_dir}/lib/qubinode_ocp4_utils.sh ]] && . ${project_dir}/lib/qubinode_ocp4_utils.sh || exit 1

    # load required files from samples to playbooks/vars/
    qubinode_required_prereqs

    # Check for OCP4 pull sceret
    check_for_pull_secret

    # Add current user to sudoers, setup global variables, run additional
    # prereqs, setup current user ssh key, ask user if they want to
    # deploy a qubinode system.
    qubinode_installer_setup

    openshift4_prechecks

    # Check if openshift cluster is already deployed and running
    check_if_cluster_deployed

    # Ensure host system is setup as a KVM host
    openshift4_kvm_health_check
    if [[ "A${KVM_IN_GOOD_HEALTH}" != "Aready"  ]]; then
        qubinode_setup_kvm_host
    fi

    # Ensure the system meets the requirement for a standard OCP deployment
    check_openshift4_size_yml

    # Checking for stale vms 
    state_check

    # Deploy IdM Server
    openshift4_idm_health_check
    if [[  "A${IDM_IN_GOOD_HEALTH}" != "Aready"  ]]; then
        qubinode_deploy_idm
    fi

    # Deploy OCP4
    ansible-playbook "${DEPLOY_OCP4_PLAYBOOK}" -e '{ check_existing_cluster: False }'  -e '{ deploy_cluster: True }' || exit $?

    # Check the OpenSHift status
    check_if_cluster_deployed
}

function qubinode_adv_openshift4 () {
    product_in_use="ocp4" # Tell the installer this is openshift3 installation
    openshift_product="${product_in_use}"
    qubinode_product_opt="${product_in_use}"
    setup_required_paths
    [[ -f ${project_dir}/lib/qubinode_kvmhost.sh ]] && . ${project_dir}/lib/qubinode_kvmhost.sh || exit 1
    [[ -f ${project_dir}/lib/qubinode_ocp4_utils.sh ]] && . ${project_dir}/lib/qubinode_ocp4_utils.sh || exit 1

    # load required files from samples to playbooks/vars/
    qubinode_required_prereqs

    # Check for OCP4 pull sceret
    check_for_pull_secret
    openshift4_prechecks
    ping_openshift4_nodes
    check_webconsole_status

    # Check if openshift cluster is already deployed and running
    check_if_cluster_deployed

    # Ensure host system is setup as a KVM host
    openshift4_kvm_health_check
    if [[ "A${KVM_IN_GOOD_HEALTH}" != "Aready"  ]]; then
        qubinode_setup_kvm_host
    fi

    # Ensure the system meets the requirement for a standard OCP deployment
    check_openshift4_size_yml

    # Checking for stale vms 
    state_check

    # Deploy IdM Server
    openshift4_idm_health_check
    if [[  "A${IDM_IN_GOOD_HEALTH}" != "Aready"  ]]; then
        echo "Could not find the IdM server."
        echo "Please run ./qubinode-installer -p idm"
    fi

    # Deploy OCP4
    DEPLOY_OCP4_PLAYBOOK="${project_dir}/playbooks/deploy_ocp4.yml"
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
    else
        exit 0
    fi
}
