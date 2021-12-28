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

    # Set the qubinode-installer directory as the project path
    if grep '""' "${vars_file}"|grep -q project_dir
    then
        #echo "Adding project_dir variable"
        sed -i "s#project_dir: \"\"#project_dir: "$project_dir"#g" "${vars_file}"
    else
        current_project_dir_value=$(awk '/^project_dir:/ {print $2}' "${vars_file}")
        if [ "${current_project_dir_value:-none}" != "${project_dir}" ]
        then
            sed -i "s#project_dir:.*#project_dir: "$project_dir"#g" "${vars_file}"
        fi
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
    libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/playbooks/vars/kvm_host.yml")
    warn_storage_profile=$(awk '/^warn_storage_profile:/ {print $2; exit}' "${project_dir}/playbooks/vars/all.yml")

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


function qcow_check () {
    # TODO: this should be removed
    libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/playbooks/vars/kvm_host.yml")
    qcow_image_name=$(grep "qcow_rhel${rhel_major}_name:" "${project_dir}/playbooks/vars/all.yml"|awk '{print $2}')

    # update IdM server with qcow image file
    if [ -f $idm_vars_file ]
    then
        sed -i "s/^cloud_init_vm_image:.*/cloud_init_vm_image: $qcow_image_name/g" $idm_vars_file
    fi


    if sudo test ! -f "${libvirt_dir}/${qcow_image_name}"
    then
        if [ -f "${project_dir}/${qcow_image_name}" ]
        then
            sudo cp "${project_dir}/${qcow_image_name}"  "${libvirt_dir}/${qcow_image_name}"
        else
            echo "  Did not find ${qcow_image_name} in path ${project_dir}."
            echo "  Download and copy ${qcow_image_name} to ${project_dir}."
            exit 1
        fi
    fi
}

function installer_artifacts_msg () {
        printf "%s\n\n" ""

        if [[ "${PULL_MISSING:-none}" == "yes" ]] && [[ "${QCOW_MISSING:-none}" == "yes" ]]
        then
            printf "%s\n" "    ${red}The installer requires the RHEL qcow image use for deploying the IdM VM.${end}"
            printf "%s\n" "    ${red}The installer also requires your OpenShift pull-secret.${end}"
            printf "%s\n\n" ""
        elif [ "${PULL_MISSING:-none}" == "yes" ]
        then
            printf "%s\n" "    ${red}The installer also requires your OpenShift pull-secret.${end}"
        elif [ "${QCOW_MISSING:-none}" == "yes" ]
        then
            printf "%s\n" "    ${red}The installer requires the RHEL qcow image use for deploying the IdM VM.${end}"
        else
            echo required_files_present >/dev/null
        fi

        printf "%s\n" "    ${yel}OPTIONS 1: RHSM offline token${end}"
        printf "%s\n" "    You can provide a file with your RHSM offline api token"
        printf "%s\n" "    to have the installer download the missing files:"
        printf "%s\n\n" "        ${blu}* ${project_dir}/rhsm-offline-token.txt${end}"
        printf "%s\n" "    ${yel}OPTION 2: Download the missing files${end}"
        printf "%s\n" "    Download the reported missing files to the expected location."
        if [ "A${PULL_MISSING}" == "Ayes" ]
        then
            printf "%s\n" "        * OpenShift Pull Secret: ${blu}${project_dir}/openshift-pull-secret.txt${end}"
        fi
        if [ "A${QCOW_MISSING}" == "Ayes" ]
        then
            printf "%s\n\n" "        * RHEL Qcow Image: ${blu}${project_dir}/$artifact_qcow_image${end}"
        fi
        printf "%s\n\n" "    Please refer to the documentation for details"
}

setup_download_options () {
    # Ensure user is setup for sudo
    setup_sudoers

    # check for pull secret
    if [ "${CHECK_PULL_SECRET:-none}" != "yes" ]
    then
        # set status to exist to prevent check for pull secret when it's not required
        PULLSECRET_STATUS="exist"
    else
        if [ -f "${project_dir}/openshift-pull-secret.txt" ]
        then
            PULLSECRET_STATUS="exist"
        else
            PULLSECRET_STATUS="notexist"
        fi
    fi

    # check for required OS qcow image or token
    TOKEN_STATUS="notexist"
    QCOW_STATUS="notexist"
    libvirt_dir=$(awk '/^kvm_host_libvirt_dir:/ {print $2}' "${project_dir}/playbooks/vars/kvm_host.yml")
    artifact_qcow_image=$(grep "qcow_rhel${rhel_major}_name:" "${project_dir}/playbooks/vars/all.yml"|awk '{print $2}')
    if sudo test -f "${libvirt_dir}/${artifact_qcow_image}"
    then
        QCOW_STATUS=exist
    else
        if [[ ! -f "${libvirt_dir}/${artifact_qcow_image}" ]] && [[ ! -f "${project_dir}/${artifact_qcow_image}" ]]
        then
            # check for user provided token
            if [ -f "{project_dir}/rhsm-offline-token.txt" ]
            then
                TOKEN_STATUS=exist
            fi
        else
            QCOW_STATUS=exist
        fi
    fi

    if [[ "${TOKEN_STATUS:-none}" == "notexist" ]] && [[ "${PULLSECRET_STATUS:-none}" == "notexist" ]]
    then
        PULL_MISSING=yes
        artifact_string="your OCP openshift-pull-secret.txt"
    fi

    if [[ "${QCOW_STATUS:-none}" == "notexist" ]] && [[ "${TOKEN_STATUS:-none}" == "notexist" ]]
    then
        QCOW_MISSING=yes
        artifact_string="the $artifact_qcow_image image"
    fi

    if  [[ "${PULL_MISSING:-none}" == "yes" ]] || [[ "${QCOW_MISSING:-none}" == "yes" ]]
    then
        if [ -f "${project_dir}/rhsm-offline-token.txt" ]
        then
           printf "%s\n" "    Required files will be downloaded as needed" >/dev/null
        else
            installer_artifacts_msg
            exit 1
        fi
    fi

    # Ensure qcow image is copied to the libvirt directory
    if sudo test ! -f "${libvirt_dir}/${artifact_qcow_image}"
    then
        if [ -f "${project_dir}/${artifact_qcow_image}" ]
        then
            sudo cp "${project_dir}/${artifact_qcow_image}"  "${libvirt_dir}/${artifact_qcow_image}"
        else
            if [ -f "${project_dir}/rhsm-offline-token.txt" ]
            then
                printf "%s\n" "    Required files will be downloaded as needed" >/dev/null
            else
                printf "%s\n" "  Did not find ${artifact_qcow_image} in path ${project_dir}."
                printf "%s\n" "  Download and copy ${artifact_qcow_image} to ${project_dir}."
                exit 1
            fi
        fi
    fi
}


download_required_redhat_files () {
    cd "${project_dir}"
    if [ -f "${project_dir}/rhsm-offline-token.txt" ]
    then
        ansible-playbook playbooks/download-redhat-files.yml
    else
        installer_artifacts_msg
    fi
}
