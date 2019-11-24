#!/bin/bash

function tower_variables () {
    tower_vars_file="${project_dir}/playbooks/vars/tower_server.yml"
    prefix=$(awk '/instance_prefix:/ {print $2;exit}' "${vars_file}")
    tower_hostname="${prefix}-${tower_name}"
    tower_webconsole="${tower_webconsole}"
    SAMPLE_VARS_FILE="${project_dir}/samples/tower_server.yml"
    TOWER_VM_PLAYBOOK="${project_dir}/playbooks/deploy_tower_vm.yml"
    TOWER_SERVER_IP=$(awk -v var="${tower_hostname}" '$0 ~ var {print $2}' "${project_dir}/inventory/hosts" |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
    TOWER_SERVER_PLAYBOOK="${project_dir}/playbooks/tower_server.yml"
    IP=$(awk -v var="${tower_hostname}" '$0 ~ var {print $0}' "${project_dir}/inventory/hosts"|grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
    tower_license="${project_dir}/tower-license.txt"

    if [ -f "${tower_vars_file}" ]
    then
        subscription_name=$(awk -F'"' '/redhat_subscription_name:/ {print $2}' "${tower_vars_file}")
        tower_name=$(awk '/tower_name_append:/ {print $2}' "${tower_vars_file}")
    fi

    if [ "A${TOWER_SERVER_IP}" != "A" ]
    then
        TOWER_SERVER_DNS=$(dig +short -x "${TOWER_SERVER_IP}")
    fi
}

function update_tower_ip () {
    tower_variables
    if [ "A${IP}" != "A" ]
    then
        if ! grep 'tower_server_ip:' "${tower_vars_file}" |grep -q $IP
        then
            sed -i "s/tower_server_ip:.*/tower_server_ip: "$IP"/g" "${tower_vars_file}"
        fi
    else
        echo "Could not find ip address for Tower server."
        exit 1
    fi
}

function update_tower_password () {
    # Load variables
    tower_variables
    # decrypt ansible vault file
    decrypt_ansible_vault "${vaultfile}"

    # Generate a ramdom passwords
    if grep '""' "${vaultfile}"|grep -q tower_pg_password
    then
        tower_pg_password=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
        sed -i "s/tower_pg_password: \"\"/tower_pg_password: "$tower_pg_password"/g" "${vaultfile}"
    fi

    if grep '""' "${vaultfile}"|grep -q tower_rabbitmq_password
    then
        tower_rabbitmq_password=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
        sed -i "s/tower_rabbitmq_password: \"\"/tower_rabbitmq_password: "$tower_rabbitmq_password"/g" "${vaultfile}"
    fi
    
    # encrypt vault password
    encrypt_ansible_vault "${vault_vars_file}"
}

function deploy_tower_vm () {
    # Load variables
    tower_variables

    # Run some prechecks before deploying the VM
    ask_user_input
    qubinode_vm_deployment_precheck
    test -f "${tower_vars_file}" || cp "${SAMPLE_VARS_FILE}" "${tower_vars_file}"

    # Load variables
    tower_variables

    # Run playbook to build Tower VM
    ansible-playbook "${TOWER_VM_PLAYBOOK}" || exit $?

    #Get VM ip
    update_tower_ip
}

function deploy_tower () {
    # Load variables
    tower_variables
    update_tower_password
    if [ ! -f "${tower_license}" ]
    then
        echo "Could not find tower-license.txt under ${project_dir}"
        echo "Please place file there and try again"
        exit 1
    fi
    ansible-playbook "${TOWER_SERVER_PLAYBOOK}" || exit $?
    
}

function qubinode_deploy_tower () {
    deploy_tower_vm
    deploy_tower
    tower_install_msg
}

function qubinode_teardown_tower () {
    # Load variables
    tower_variables
    # Run playbook to build Tower VM
    ansible-playbook "${TOWER_VM_PLAYBOOK}" --extra-vars "vm_teardown=true" || exit $?
}

function tower_server_maintenance () {
   tower_variables
   STATUS=$(sudo virsh list --all|awk -v var="${tower_hostname}" '$0 ~ var {print $3}')
   if [ "${product_maintenance}" == "shutdown" ]
   then
       if [ "A${STATUS}" == "Arunning" ]
       then
           echo "Shutting down Tower VM: ${tower_hostname}"
           ansible "${tower_hostname}" -m shell -a "shutdown -h now" -i "${project_dir}/inventory/hosts" -b 
       fi
   elif [ "${product_maintenance}" == "start" ]
   then
       if [ "A${STATUS}" != "Arunning" ]
       then
           echo "Starting Up Tower VM: ${tower_hostname}"
           sudo virsh start "${tower_hostname}"
       fi
   fi
   exit 0
}


function tower_install_msg () {
    tower_variables
    printf "\n\n********************************************************************\n"
    printf "* The Tower server VM appears to be deployed and in good state *\n\n"
    printf "    Web Url: ${tower_webconsole} \n"
    printf "    Username: $(whoami) \n"
    printf "    Password: the vault variable *admin_user_password* \n\n"
    printf "Run: ansible-vault edit ${project_dir}/playbooks/vars/vault.yml \n"
    printf "*******************************************************************************\n\n"
}


function qubinode_deploy_tower () {
    # Load variables
    tower_variables

    # Run maitenance options if -m argument passed
    if [ "A${product_maintenance}" != "A" ]
    then
        tower_server_maintenance
    fi

    # Run some prechecks before deploying the VM
    ask_user_input
    qubinode_vm_deployment_precheck
    test -f "${tower_vars_file}" || cp "${SAMPLE_VARS_FILE}" "${tower_vars_file}"

    # set subscription pool id
    get_subscription_pool_id '"${subscription_name}"'
    if [ "A${POOL_ID}" != "A" ]
    then
        echo "Setting RHSM pool-id"
        if grep '""' "${tower_vars_file}"|grep -q tower_pool_id
        then
            echo "${tower_vars_file} tower_pool_id variable"
            sed -i "s/tower_pool_id: \"\"/tower_pool_id: $POOL_ID/g" "${tower_vars_file}"
        fi
    else
        echo "The ${subsription_name} Pool ID is not available to playbooks/vars/all.yml"
    fi

   # Ensure required role exist
   check_for_required_role swygue.ansible-tower

   # Deploy or teardown Tower
   if [ "A${teardown}" == "Atrue" ]
   then
       if [ "A${TOWER_SERVER_DNS}" != "A" ]
       then
          echo "Removing Satelite DNS records"
          ansible-playbook "${TOWER_VM_PLAYBOOK}" --extra-vars "vm_teardown=true" -t create_dns_records || exit $?
       fi

       if sudo virsh list | grep -q "${tower_hostname}"
       then
           echo "Removing Tower VM"
           ansible-playbook "${TOWER_VM_PLAYBOOK}" --extra-vars "vm_teardown=true" --skip-tags create_dns_records || exit $?
       fi
   else
       echo "Checking if Tower deployment is needed"
       if [ "A${TOWER_SERVER_IP}" != "A" ]
       then
           if ! ssh -o StrictHostKeyChecking=no "${ADMIN_USER}@${TOWER_SERVER_IP}" 'exit'
           then
               echo "Deploy Tower VM and create DNS records"
               qubinode_deploy_idm
               ansible-playbook "${TOWER_VM_PLAYBOOK}" || exit $?
               update_tower_ip
               ansible-playbook "${TOWER_SERVER_PLAYBOOK}" || exit $?
               tower_install_msg
           elif [ "A${TOWER_SERVER_DNS}" == "A" ]
           then
               echo "Create Tower server DNS records"
               qubinode_deploy_idm
               ansible-playbook "${TOWER_VM_PLAYBOOK}" -t create_dns_records || exit $?
               update_tower_ip
               ansible-playbook "${TOWER_SERVER_PLAYBOOK}" || exit $?
               tower_install_msg
           else
               # need to add a check to verify login to the satellite server then
               # and if not run other steps
               ansible-playbook "${TOWER_VM_PLAYBOOK}" -t create_dns_records || exit $?
               update_tower_ip
               ansible-playbook "${TOWER_SERVER_PLAYBOOK}" || exit $?
               tower_install_msg
           fi
       else
           echo "Deploy Tower VM and create DNS records"
           qubinode_deploy_idm
           ansible-playbook "${TOWER_VM_PLAYBOOK}" || exit $?
           update_tower_ip
           ansible-playbook "${TOWER_SERVER_PLAYBOOK}" || exit $?
           tower_install_msg
       fi
   fi
}
