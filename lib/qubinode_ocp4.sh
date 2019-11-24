#!/bin/bash

function openshift4_variables () {
    ocp4_vars_file="${project_dir}/playbooks/vars/ocp4.yml"
    ocp4_sample_vars="${project_dir}/samples/ocp4.yml"
    ocp4_pull_secret="${project_dir}/pull-secret.txt"
}

function openshift4_prechecks () {
    openshift4_variables
    if [ ! -f "${ocp4_vars_file}" ]
    then
        cp "${ocp4_sample_vars}" "${ocp4_vars_file}"
    fi

    #check for pull secret 
    if [ ! -f "${ocp4_pull_secret}" ]
    then
        echo "Please download your pull-secret from: "
        echo "https://cloud.redhat.com/openshift/install/metal/user-provisioned"
        echo "and save it as ${ocp4_pull_secret}"
        echo ""
        exit 
    fi

    check_for_required_role openshift-4-loadbalancer

    # Ensure firewall rules
    if ! sudo firewall-cmd --list-ports | grep -q '32700/tcp'
    then
        echo "Setting firewall rules"
        sudo firewall-cmd --add-port={80/tcp,443/tcp,6443/tcp,22623/tcp,32700/tcp} --permanent
        sudo firewall-cmd --reload
    fi
}

openshift4_qubinode_teardown () {
    echo "Hello World"
}

openshift4_server_maintenance () {
    echo "Hello World"
}

openshift4_enterprise_deployment () {
    openshift4_prechecks
    #ansible-playbook playbooks/ocp4_01_deployer_node_setup.yml
    #ansible-playbook playbooks/ocp4_02_configure_dns_entries.yml
    #ansible-playbook playbooks/ocp4_03_configure_lb.yml
    #ansible-playbook playbooks/ocp4_04_download_openshift_artifacts.yml
    ansible-playbook playbooks/ocp4_05_create_ignition_configs.yml
}
