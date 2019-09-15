#!/bin/bash

# Ensure RHEL is set to the supported release
function set_rhel_release () {
    RHEL_RELEASE=$(awk '/rhel_release/ {print $2}' samples/all.yml |grep [0-9])
    RELEASE="Release: ${RHEL_RELEASE}"
    CURRENT_RELEASE=$(sudo subscription-manager release --show)

    if [ "A${RELEASE}" != "A${CURRENT_RELEASE}" ]
    then
        echo "Setting RHEL to the supported release: ${RHEL_RELEASE}"
        sudo subscription-manager release --unset
        sudo subscription-manager release --set="${RHEL_RELEASE}"
    else
       echo "RHEL release is set to the supported release: ${CURRENT_RELEASE}"
    fi
}

function qubinode_networking () {
    IPADDR=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    # HOST Gateway not currently in use
    GTWAY=$(ip route get 8.8.8.8 | awk -F"via " 'NR==1{split($2,a," ");print a[1]}')
    NETWORK=$(ip route | awk -F'/' "/$IPADDR/ {print \$1}")
    PTR=$(echo "$NETWORK" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'|sed 's/0.//g')
    DEFINED_BRIDGE=$(awk '/qubinode_brdige_name/ {print $2;exit 1 }' playbooks/vars/all.yml)
    CURRENT_DEFAULT_INTERFACE=$(sudo route | grep '^default' | awk '{print $8}')
    if [ "A${CURRENT_DEFAULT_INTERFACE}" == "A${DEFINED_BRIDGE}" ]
    then
      DEFAULT_INTERFACE=$(sudo brctl show qubibr0 | awk '/qubibr0/ {print $4}')
    else
      DEFAULT_INTERFACE=$(ip route list | awk '/^default/ {print $5}')
    fi
    NETMASK_PREFIX=$(ip -o -f inet addr show $DEFAULT_INTERFACE | awk '{print $4}'|cut -d'/' -f2)
}

function setup_sudoers () {
    prereqs
    echo "Checking if ${CURRENT_USER} is setup for password-less sudo: "
    elevate_cmd test -f "/etc/sudoers.d/${CURRENT_USER}"
    if [ "A$?" != "A0" ]
    then
        SUDOERS_TMP=$(mktemp)
        echo "Setting up /etc/sudoers.d/${CURRENT_USER}"
	echo "${CURRENT_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_TMP}"
        elevate_cmd cp "${SUDOERS_TMP}" "/etc/sudoers.d/${CURRENT_USER}"
        sudo chmod 0440 "/etc/sudoers.d/${CURRENT_USER}"
    else
        echo "${CURRENT_USER} is setup for password-less sudo"
    fi
}

function setup_user_ssh_key () {
    HOMEDIR=$(eval echo ~${CURRENT_USER})
    if [ ! -f "${HOMEDIR}/.ssh/id_rsa.pub" ]
    then
        echo "Setting up ssh keys for ${CURRENT_USER}"
        ssh-keygen -f "${HOMEDIR}/.ssh/id_rsa" -q -N ''
    fi
}

function qubinode_installer_preflight () {
    setup_sudoers
    prereqs
    qubinode_networking
    setup_user_ssh_key
    setup_variables
    ask_user_input

    # Setup admin user variable
    if grep '""' "${vars_file}"|grep -q admin_user
    then
        echo "Updating ${vars_file} admin_user variable"
        sed -i "s#admin_user: \"\"#admin_user: "$CURRENT_USER"#g" "${vars_file}"
    fi

    # Pull variables from all.yml needed for the install
    domain=$(awk '/^domain:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
}

function qubinode_setup_kvm_host () {
    prereqs
    # check for host inventory file
    if [ ! -f "${hosts_inventory_dir}/hosts" ]
    then
        echo "Inventory file ${hosts_inventory_dir}/hosts is missing"
        echo "Please run qubinode-installer -m setup"
        echo ""
        exit 1
    fi

    # check for inventory directory
    if [ -f "${vars_file}" ]
    then
        if grep '""' "${vars_file}"|grep -q inventory_dir
        then
            echo "No value set for inventory_dir in ${vars_file}"
            echo "Please run qubinode-installer -m setup"
            echo ""
            exit 1
        fi
     else
        echo "${vars_file} is missing"
        echo "Please run qubinode-installer -m setup"
        echo ""
        exit 1
     fi

    # Check for ansible and ansible role
    ROLE_PRESENT=$(ansible-galaxy list | grep 'swygue.edge_host_setup')
    if [ ! -f /usr/bin/ansible ]
    then
        echo "Ansible is not installed"
        echo "Please run qubinode-installer -m ansible"
        echo ""
        exit 1
    elif [ "A${ROLE_PRESENT}" == "A" ]
    then
        echo "Required role swygue.edge_host_setup is missing."
        echo "Please run run qubinode-installer -m ansible"
        echo ""
        exit 1
    fi

    # future check for pool id
    #if grep '""' "${vars_file}"|grep -q openshift_pool_id
    #then
    ansible-playbook "${project_dir}/playbooks/setup_kvmhost.yml" || exit $?
}