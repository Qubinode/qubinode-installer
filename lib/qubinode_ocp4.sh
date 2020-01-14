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

    # Ensure host system is setup as a KVM host
    qubinode_setup_kvm_host

    # Deploy IdM Server
    qubinode_deploy_idm
 
    # Deploy OCP4
    openshift4_enterprise_deployment
}
