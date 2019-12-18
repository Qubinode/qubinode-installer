#!/bin/bash

function qubinode_required_prereqs () {
    # This function copies over the required variables files
    # Setup of the required paths
    # Sets up the inventory file

    echo "Loading function qubinode_required_prereqs"
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
    domain=$(awk '/^domain:/ {print $2}' "${vars_file}")
    deploy_idm_server=$(awk '/deploy_idm_server:/ {print $2}' "${vars_file}")

    # copy sample vars file to playbook/vars directory
    if [ ! -f "${vars_file}" ]
    then
      cp "${project_dir}/samples/all.yml" "${vars_file}"
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
    if [ ! -f "${ocp3_vars_file}" ]
    then
        cp "${project_dir}/samples/ocp3.yml" "${ocp3_vars_file}"
    fi

    # copy sample okd3 file to playbook/vars directory
    if [ ! -f "${okd3_vars_file}" ]
    then
        cp "${project_dir}/samples/okd3.yml" "${okd3_vars_file}"
    fi

    # create ansible inventory file
    if [ ! -f "${hosts_inventory_dir}/hosts" ]
    then
        cp "${project_dir}/samples/hosts" "${hosts_inventory_dir}/hosts"
    fi
}

function setup_variables () {
    qubinode_required_prereqs

    echo ""
    #echo "Populating ${vars_file}"

    # add inventory file to all.yml
    if grep '""' "${vars_file}"|grep -q inventory_dir
    then
        echo "Adding inventory_dir variable"
        sed -i "s#inventory_dir: \"\"#inventory_dir: "$hosts_inventory_dir"#g" "${vars_file}"
    fi

    # Set KVM project dir
    if grep '""' "${vars_file}"|grep -q project_dir
    then
        echo "Adding project_dir variable"
        sed -i "s#project_dir: \"\"#project_dir: "$project_dir"#g" "${vars_file}"
    fi

    # Setup admin user variable
    if grep '""' "${vars_file}"|grep -q admin_user
    then
        echo "Updating ${vars_file} admin_user variable"
        sed -i "s#admin_user: \"\"#admin_user: "$CURRENT_USER"#g" "${vars_file}"
    fi

    # Pull variables from all.yml needed for the install
    domain=$(awk '/^domain:/ {print $2}' "${vars_file}")
    echo ""

    # Check if we should setup qubinode
    QUBINODE_SYSTEM=$(awk '/run_qubinode_setup:/ {print $2; exit}' "${vars_file}" | tr -d '"')

    # Satellite server vars file
    SATELLITE_VARS_FILE="${project_dir}/playbooks/vars/satellite_server.yml"

    VM_DATA_DIR=$(awk '/^vm_data_dir:/ {print $2}' ${vars_file}|tr -d '"')
    ADMIN_USER=$(awk '/^admin_user:/ {print $2;exit}' "${vars_file}")
}

function qubinode_vm_deployment_precheck () {
   # This function ensure that the host is setup as a KVM host.
   # It ensures the foundation is set to allow ansible playbooks can run
   # and the products can be deployed.
   qubinode_required_prereqs
   setup_variables
   ask_user_input
   echo "Running VM deployment prechecks"
   if [ "A${teardown}" != "Atrue" ]
   then
       # Ensure the setup function as was executed
       if [ ! -f "${vars_file}" ]
       then
           qubinode_installer_preflight
       fi

       # Check if KVM HOST is ready
       echo "Verifying KVM host is setup"
       qubinode_check_kvmhost

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

       # Check for required Qcow image
       check_for_rhel_qcow_image
    fi
}

function check_for_rhel_qcow_image () {
    # check for required OS qcow image and copy it to right location
    libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/samples/all.yml")
    os_qcow_image=$(awk '/^os_qcow_image_name/ {print $2}' "${project_dir}/samples/all.yml")
    if [ ! -f "${libvirt_dir}/${os_qcow_image}" ]
    then
        echo "INSIDE FIRST BLOCK"
        if [ -f "${project_dir}/${os_qcow_image}" ]
        then
            sudo cp "${project_dir}/${os_qcow_image}" "${libvirt_dir}/${os_qcow_image}"
        else
            echo "Could not find ${project_dir}/${os_qcow_image}, please download the ${os_qcow_image} to ${project_dir}."
            echo "Please refer the documentation for additional information."
            exit 1
        fi
    fi
}


