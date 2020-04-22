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
}


function qubinode_autoinstall_openshift4 () {
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

    # Add current user to sudoers, setup global variables, run additional
    # prereqs, setup current user ssh key, ask user if they want to
    # deploy a qubinode system.
    qubinode_installer_setup


    openshift4_prechecks

    ping_openshift4_nodes
    check_webconsole_status

    if [[ "A${IS_OPENSHIFT4_NODES}" == "Ayes" ]] && [ $WEBCONSOLE_STATUS -eq 200 ]
    then
      printf "%s\n\n" " ${grn}OpenShift Cluster is already deployed${end}"
      #printf "%s\n\n" " ${grn}Access the OpenShift web-console here: https://console-openshift-console.apps.ocp42.${domain}${end}"
      #printf "%s\n\n" " ${grn}Login to the console with user: kubeadmin, password:$(cat ocp4/auth/kubeadmin-password)${end}"
      ansible-playbook ${project_dir}/playbooks/ocp4-check-cluster.yml || exit $?
    else
        check_openshift4_size_yml

        # Ensure host system is setup as a KVM host
        openshift4_kvm_health_check
        if [[ "A${KVM_IN_GOOD_HEALTH}" != "Aready"  ]]; then
          qubinode_setup_kvm_host
        fi

        # Deploy IdM Server
        openshift4_idm_health_check
        if [[  "A${IDM_IN_GOOD_HEALTH}" != "Aready"  ]]; then
          qubinode_deploy_idm
        fi

        # Deploy OCP4
        DEPLOY_OCP4_PLAYBOOK="${project_dir}/playbooks/deploy_ocp4.yml"
        ansible-playbook "${DEPLOY_OCP4_PLAYBOOK}" || exit $?

        # Check the OpenSHift status
        ansible-playbook ${project_dir}/playbooks/ocp4-check-cluster.yml || exit $?
    fi
}

function openshift4_qubinode_teardown () {
    confirm " Are you sure you want to delete the OpenShift 4 cluster? yes/no"
    if [ "A${response}" == "Ayes" ]
    then
        DEPLOY_OCP4_PLAYBOOK="${project_dir}/playbooks/deploy_ocp4.yml"
        ansible-playbook "${DEPLOY_OCP4_PLAYBOOK}" -e tear_down=yes || exit $?
    else
        exit 0
    fi
}
