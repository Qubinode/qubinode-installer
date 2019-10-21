#!/bin/bash



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
            echo "Could not find ${project_dir}/${os_qcow_image}, please download the ${os_qcow_image} to ${project_dir}."
            echo "Please refer the documentation for additional information."
            exit 1
        fi
    else
        echo "The require OS image ${libvirt_dir}/${os_qcow_image} was found."
    fi
}

function qubinode_project_cleanup () {
    prereqs
    FILES=()
    mapfile -t FILES < <(find "${project_dir}/inventory/" -not -path '*/\.*' -type f)
    if [ -f "$vault_vars_file" ] && [ -f "$vault_vars_file" ]
    then
        FILES=("${FILES[@]}" "$vault_vars_file" "$vars_file")
    fi

    product_opt=$(awk '/^product:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
    if [[ ${product_opt} == "ocp3" ]]; then
      FILES=("${FILES[@]}" "$ocp3_vars_file")
    elif [[ ${product_opt} == "okd3" ]]; then
      FILES=("${FILES[@]}" "$okd3_vars_file")
    fi

    if [ ${#FILES[@]} -eq 0 ]
    then
        echo "Project directory: ${project_dir} state is already clean"
    else
        for f in $(echo "${FILES[@]}")
        do
            test -f $f && rm $f
            echo "purged $f"

        done
    fi
}


function prereqs () {
    # This function copies over the required variables files
    # Setup of the required paths
    # Sets up the inventory file

    # setup required paths
    setup_required_paths
    vault_key_file="/home/${CURRENT_USER}/.vaultkey"
    vault_vars_file="${project_dir}/playbooks/vars/vault.yml"
    vars_file="${project_dir}/playbooks/vars/all.yml"
    hosts_inventory_dir="${project_dir}/inventory"
    inventory_file="${hosts_inventory_dir}/hosts"
    ocp3_vars_file="${project_dir}/playbooks/vars/ocp3.yml"
    okd3_vars_file="${project_dir}/playbooks/vars/okd3.yml"

    # copy sample vars file to playbook/vars directory
    if [ ! -f "${vars_file}" ]
    then
      cp "${project_dir}/samples/all.yml" "${vars_file}"
    fi

    # create vault vars file
    if [ ! -f "${vault_vars_file}" ]
    then
        cp "${project_dir}/samples/vault.yml" "${vault_vars_file}"
    fi

    # create ocp3 vars file
    if [ ! -f "${ocp3_vars_file}" ]
    then
        cp "${project_dir}/samples/ocp3.yml" "${ocp3_vars_file}"
    fi

    # create ocp3 vars file
    if [ ! -f "${okd3_vars_file}" ]
    then
        cp "${project_dir}/samples/okd3.yml" "${okd3_vars_file}"
    fi

    # create ansible inventory file
    if [ ! -f "${hosts_inventory_dir}/hosts" ]
    then
        cp "${project_dir}/samples/hosts" "${hosts_inventory_dir}/hosts"
    fi

    # setting OpenShift Product Type
    product_opt=$(awk '/^product:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
    echo "${product_opt}" || exit 1
    if grep 'ocp3' "${vars_file}"|grep -q "product:"
    then
        echo "Updating OpenShift Product Type"
        sed -i "s/product:.*/product: okd3/" "${vars_file}"
    fi

    if [[  ${product_opt} == "okd" ]]; then
      if grep 'rhsm_setup_insights_client: true' "${vars_file}"|grep -q "product:"
      then
          echo "Disable Red Hat insights on OKD Deploument"
          sed -i "s/rhsm_setup_insights_client:.*/rhsm_setup_insights_client: false/" "${vars_file}"
      fi
    fi
}

