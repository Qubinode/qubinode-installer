#!/bin/bash

function product_requirements () {
    # This function copies over the required variables files
    # Setup of the required paths
    # Sets up the inventory file

    # setup required paths
    setup_required_paths
    vault_key_file="/home/${CURRENT_USER}/.vaultkey"
    vault_vars_file="${project_dir}/playbooks/vars/vault.yml"
    vars_file="${project_dir}/playbooks/vars/all.yml"
    idm_vars_file="${project_dir}/playbooks/vars/all.yml"
    hosts_inventory_dir="${project_dir}/inventory"
    inventory_file="${hosts_inventory_dir}/hosts"
    ocp3_vars_file="${project_dir}/playbooks/vars/ocp3.yml"
    okd3_vars_file="${project_dir}/playbooks/vars/okd3.yml"

    # copy sample vars file to playbook/vars directory
    if [ ! -f "${vars_file}" ]
    then
      cp "${project_dir}/samples/all.yml" "${vars_file}"
    fi

    if [ ! -f "${idm_vars_file}" ]
    then
      cp "${project_dir}/samples/idm.yml" "${idm_vars_file}"
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
    #echo "${product_opt}" || exit 1
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

function setup_variables () {
    product_requirements

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
    QUBINODE_SYSTEM=$(awk '/run_qubinode_setup/ {print $2; exit}' "${vars_file}" | tr -d '"')

    # Check if we should setup qubinode
    DNS_SERVER_NAME=$(awk -F'-' '/idm_hostname:/ {print $2; exit}' "${vars_file}" | tr -d '"')

    # Satellite server vars file
    SATELLITE_VARS_FILE="${project_dir}/playbooks/vars/satellite_server.yml"

    VM_DATA_DIR=$(awk '/^vm_data_dir:/ {print $2}' ${vars_file}|tr -d '"')
    ADMIN_USER=$(awk '/^admin_user:/ {print $2;exit}' "${vars_file}")
}

function qubinode_installer_setup () {
    # Run required functions
    setup_sudoers
    product_requirements
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

function qubinode_project_cleanup () {
    # ensure requirements are in place
    product_requirements

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

function qubinode_vm_deployment_precheck () {
   # This function ensure that the host is setup as a KVM host.
   # It ensures the foundation is set to allow ansible playbooks can run
   # and the products can be deployed.
   product_requirements
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
           STATUS=$(ansible-galaxy list | grep ansible-role-rhel7-kvm-cloud-init >/dev/null 2>&1; echo $?)
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


function qubinode_product_deployment () {
    # this function deploys a supported product
    PRODUCT_OPTION=$1
    AVAIL_PRODUCTS="ocp3 ocp4 satellite idm kvmhost"
    case $PRODUCT_OPTION in
          ocp3)
              echo "Installing ocp3"
              are_nodes_deployed
              qubinode_run_openshift_installer
              ;;
          ocp4)
              echo "Installing ocp4"
              ;;
          satellite)
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_teardown_satellite
              else
                  echo "Installing Satellite"
                  qubinode_deploy_satellite
              fi
              ;;
          idm)
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_teardown_idm
              else
                  qubinode_deploy_idm
              fi
              ;;
          kvmhost)
              echo "Setting up KVM host"
              qubinode_setup_kvm_host
              ;;
          *)
              echo "Product ${PRODUCT_OPTION} is not supported."
              echo "Supported products are: ${AVAIL_PRODUCTS}"
              exit 1
              ;;
    esac
           
}

function qubinode_maintenance_options () {
    if [ "${qubinode_maintenance_opt}" == "clean" ]
    then
        qubinode_project_cleanup
    elif [ "${qubinode_maintenance_opt}" == "setup" ]
    then
        qubinode_installer_setup
    elif [ "${qubinode_maintenance_opt}" == "rhsm" ]
    then
        qubinode_rhsm_register
    elif [ "${qubinode_maintenance_opt}" == "ansible" ]
    then
        qubinode_setup_ansible
    elif [ "${qubinode_maintenance_opt}" == "host" ] || [ "${maintenance}" == "kvmhost" ]
    then
        qubinode_setup_kvm_host
    elif [ "${qubinode_maintenance_opt}" == "deploy_nodes" ]
    then
        qubinode_vm_manager deploy_nodes
    elif [ "${qubinode_maintenance_opt}" == "undeploy" ]
    then
        #TODO: this should remove all VMs and clean up the project folder
        qubinode_vm_manager undeploy
    elif [ "${qubinode_maintenance_opt}" == "uninstall_openshift" ]
    then
      #TODO: this should remove all VMs and clean up the project folder
        qubinode_uninstall_openshift
    else
        display_help
    fi
}

