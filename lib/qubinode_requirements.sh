#!/bin/bash

function qubinode_required_prereqs () {
    # This function copies over the required variables files
    # Setup of the required paths
    # Sets up the inventory file

    # setup required paths
    setup_required_paths
    vault_key_file="/home/${CURRENT_USER}/.vaultkey"
    vault_vars_file="${project_dir}/playbooks/vars/vault.yml"
    vars_file="${project_dir}/playbooks/vars/all.yml"
    idm_vars_file="${project_dir}/playbooks/vars/idm.yml"
    hosts_inventory_dir="${project_dir}/inventory"
    inventory_file="${hosts_inventory_dir}/hosts"
    ocp3_vars_file="${project_dir}/playbooks/vars/ocp3.yml"
    okd3_vars_file="${project_dir}/playbooks/vars/okd3.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
    generate_all_yaml_script="${project_dir}/lib/generate_all_yaml.sh"

    # copy sample vars file to playbook/vars directory
    if [ ! -f "${vars_file}" ]
    then
      cp "${project_dir}/samples/all.yml" "${vars_file}"
    fi

    # copy sample kvm host vars
    if [ ! -f "${kvm_host_vars_file}" ]
    then
      cp "${project_dir}/samples/kvm_host.yml" "${kvm_host_vars_file}"
    fi

    if [ ! -f "${idm_vars_file}" ]
    then
     cp "${project_dir}/samples/idm.yml" "${idm_vars_file}"
    fi

    # copy sample vault file to playbook/vars directory
    if [ ! -f "${vault_vars_file}" ]
    then
        cp "${project_dir}/samples/vault.yml" "${vault_vars_file}"
    fi

    # copy sample ocp3 file to playbook/vars directory
    if [ "A${qubinode_product_opt}" == "Aocp3" ]
    then
        if [ ! -f "${ocp3_vars_file}" ]
        then
            cp "${project_dir}/samples/ocp3.yml" "${ocp3_vars_file}"
        fi
    fi

    # copy sample okd3 file to playbook/vars directory
    if [ "A${qubinode_product_opt}" == "Aokd3" ]
    then
        if [ ! -f "${okd3_vars_file}" ]
        then
            cp "${project_dir}/samples/okd3.yml" "${okd3_vars_file}"
        fi
    fi

    # create ansible inventory file
    if [ ! -f "${hosts_inventory_dir}/hosts" ]
    then
        cp "${project_dir}/samples/hosts" "${hosts_inventory_dir}/hosts"
    fi

    # Get domain
    domain=$(awk '/^domain:/ {print $2}' "${vars_file}")
}

function setup_variables () {
    qubinode_required_prereqs

    # add inventory file to all.yml
    if grep '""' "${vars_file}"|grep -q inventory_dir
    then
        #echo "Adding inventory_dir variable"
        sed -i "s#inventory_dir: \"\"#inventory_dir: "$hosts_inventory_dir"#g" "${vars_file}"
    fi

    # Set KVM project dir
    if grep '""' "${vars_file}"|grep -q project_dir
    then
        #echo "Adding project_dir variable"
        sed -i "s#project_dir: \"\"#project_dir: "$project_dir"#g" "${vars_file}"
    fi

    # Setup admin user variable
    if grep '""' "${vars_file}"|grep -q admin_user
    then
        #echo "Updating ${vars_file} admin_user variable"
        sed -i "s#admin_user: \"\"#admin_user: "$CURRENT_USER"#g" "${vars_file}"
    fi

    # Set the RHEL version
    if grep '""' "${vars_file}"|grep -q rhel_version
    then
        return_os_version=$(get_rhel_version)
        sed -i "s#rhel_version: \"\"#rhel_version: "$return_os_version"#g" "${vars_file}"
    fi

    # pull domain from all.yml
    domain=$(awk '/^domain:/ {print $2}' "${vars_file}")
    echo ""

    # Check if we should setup qubinode
    #QUBINODE_SYSTEM=$(awk '/run_qubinode_setup:/ {print $2; exit}' "${vars_file}" | tr -d '"')

    # Satellite server vars file
    SATELLITE_VARS_FILE="${project_dir}/playbooks/vars/satellite_server.yml"

    VM_DATA_DIR=$(awk '/^vm_data_dir:/ {print $2}' ${vars_file}|tr -d '"')
    ADMIN_USER=$(awk '/^admin_user:/ {print $2;exit}' "${vars_file}")

    # load kvmhost variables
    kvm_host_variables

    setup_completed=$(awk '/qubinode_installer_setup_completed:/ {print $2;exit}' "${vars_file}")
    rhsm_completed=$(awk '/qubinode_installer_rhsm_completed:/ {print $2;exit}' "${vars_file}")
    ansible_completed=$(awk '/qubinode_installer_ansible_completed:/ {print $2;exit}' "${vars_file}")
    #host_completed=$(awk '/qubinode_installer_host_completed:/ {print $2;exit}' "${vars_file}")
    base_setup_completed=$(awk '/qubinode_base_reqs_completed:/ {print $2;exit}' "${vars_file}")
}

function get_rhel_version() {
  if cat /etc/redhat-release  | grep 8.[0-9] > /dev/null 2>&1; then
    echo "RHEL8"
  elif cat /etc/redhat-release  | grep 7.[0-9] > /dev/null 2>&1; then
    echo  "RHEL7"
  else
    echo "Operating System not supported"
  fi

}

function qubinode_base_requirements () {
# Ensures the system is ready for VM deployment.

    setup_variables
    # Ensure ./qubinode-installer -m setup is completed
    if [ "A${setup_completed}" == "Ano" ]
    then
       qubinode_installer_setup
    fi

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

    sed -i "s/qubinode_base_reqs_completed:.*/qubinode_base_reqs_completed: yes/g" "${vars_file}"
}

function qubinode_vm_deployment_precheck () {
# Ensures the system is ready for VM deployment.

    qubinode_base_requirements
    # Ensure the ansible function has bee executed
    if [ ! -f /usr/bin/ansible ]
    then
        qubinode_setup_ansible
    else
        STATUS=$(ansible-galaxy list | grep deploy-kvm-vm >/dev/null 2>&1; echo $?)
        if [ "A${STATUS}" != "A0" ]
        then
            qubinode_setup_ansible
        fi
    fi

    # Ensure ./qubinode-installer -m host is completed
    if [ "A${host_completed}" == "Ano" ]
    then
       qubinode_setup_kvm_host
    fi

    # Check for required Qcow image
    check_for_rhel_qcow_image
}

function check_for_rhel_qcow_image () {
    # check for required OS qcow image and copy it to right location
    libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/samples/all.yml")
    os_qcow_image=$(awk '/^os_qcow_image_name/ {print $2}' "${project_dir}/samples/all.yml")
    if [ ! -f "${libvirt_dir}/${os_qcow_image}" ]
    then
        if [ -f "${project_dir}/${os_qcow_image}" ]
        then
            sudo cp "${project_dir}/${os_qcow_image}" "${libvirt_dir}/${os_qcow_image}"
        else
            printf "%s\n\n" ""
            printf "%s\n" " Could not find ${red}${project_dir}/${os_qcow_image}${end},"
            printf "%s\n\n" " please download the ${yel}${os_qcow_image}${end} to ${blu}${project_dir}${end}."
            printf "%s\n\n" " ${cyn}Please refer the documentation for additional information.${end}"
            exit 1
        fi
    fi
}


function pre_check_for_rhel_qcow_image () {
    # check for required OS qcow image and copy it to right location
    libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/samples/all.yml")
    os_qcow_image=$(awk '/^os_qcow_image_name/ {print $2}' "${project_dir}/samples/all.yml")
    if [ ! -f "${libvirt_dir}/${os_qcow_image}" ]
    then
        if [ ! -f "${project_dir}/${os_qcow_image}" ]
        then
            printf "%s\n\n" ""
            printf "%s\n" " Could not find ${red}${project_dir}/${os_qcow_image}${end},"
            printf "%s\n\n" " please download the ${yel}${os_qcow_image}${end} to ${blu}${project_dir}${end}."
            printf "%s\n\n" " ${cyn}Please refer the documentation for additional information.${end}"
            exit 1
        fi
    fi
}
