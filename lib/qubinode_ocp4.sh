#!/bin/bash

function qubinode_autoinstall_openshift4 (){
    product_in_use="ocp4" # Tell the installer this is openshift3 installation
    openshift_product="${product_in_use}"
    qubinode_product_opt="${product_in_use}"

    # load required files from samples to playbooks/vars/
    qubinode_required_prereqs

    # Add current user to sudoers, setup global variables, run additional
    # prereqs, setup current user ssh key, ask user if they want to
    # deploy a qubinode system.
    qubinode_installer_setup

    openshift4_prechecks
    
    ping_openshift4_nodes
    check_webconsole_status

    if [[ "A${IS_OPENSHIFT4_NODES}" == "Ayes" ]] && [[ $WEBCONSOLE_STATUS -eq 200 ]]
    then
      printf "%s\n\n" " ${grn}OpenShift Cluster is already deployed${end}"
      printf "%s\n\n" " ${grn}Access the OpenShift web-console here: https://console-openshift-console.apps.ocp42.${domain}${end}"
      printf "%s\n\n" " ${grn}Login to the console with user: kubeadmin, password:$(cat ocp4/auth/kubeadmin-password)${end}"
    else

        # Ensure host system is setup as a KVM host
        qubinode_setup_kvm_host

        # Deploy IdM Server
        qubinode_deploy_idm

        # Deploy OCP4
        openshift4_enterprise_deployment
        exit 0
    fi


}
