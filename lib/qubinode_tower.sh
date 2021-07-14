#!/bin/bash

function tower_variables () {
    tower_vars_file="${project_dir}/playbooks/vars/tower_server.yml"
    prefix=$(awk '/instance_prefix:/ {print $2;exit}' "${vars_file}")
    if [ "A${QUBINODE_SYSTEM}" != "Ayes" ]
    then
        tower_hostname="tower01"
        sed -i "s/tower_server_hostname:.*/tower_server_hostname: $tower_hostname/g" "${tower_vars_file}"
    else
        tower_hostname="${prefix}-${tower_name}"
    fi
    tower_webconsole="https://${tower_hostname}.${domain}"
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

    # Get python interpreter
    #ansible_python_interpreter=$(awk '/ansible_python_interpreter:/ {print $2;exit}' "${vars_file}")
}


function update_tower_password () {
    # Load variables
    tower_variables
    # decrypt ansible vault file
    decrypt_ansible_vault "${vault_vars_file}" > /dev/null

    # Generate a ramdom passwords
    if grep '""' "${vault_vars_file}"|grep -q tower_pg_password
    then
        tower_pg_password=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
        sed -i "s/tower_pg_password: \"\"/tower_pg_password: "$tower_pg_password"/g" "${vault_vars_file}"
    fi

    if grep '""' "${vault_vars_file}"|grep -q tower_rabbitmq_password
    then
        tower_rabbitmq_password=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
        sed -i "s/tower_rabbitmq_password: \"\"/tower_rabbitmq_password: "$tower_rabbitmq_password"/g" "${vault_vars_file}"
    fi
    
    # encrypt vault password
    encrypt_ansible_vault "${vault_vars_file}" >/dev/null
}
function state_check(){
cat << EOF
    ${yel}**************************************** ${end}
    ${mag}Checking Machine for stale tower vm ${end}
    ${yel}**************************************** ${end}
EOF
    clean_up_stale_vms tower
}


function deploy_tower_vm () {
    # Run some prechecks before deploying the VM
    qubinode_vm_deployment_precheck
    test -f "${tower_vars_file}" || cp "${SAMPLE_VARS_FILE}" "${tower_vars_file}"

    # Load variables
    tower_variables

    # Check for stale vms 
    state_check

    # Run playbook to build Tower VM
    ansible-playbook "${TOWER_VM_PLAYBOOK}" || exit $?
}

function deploy_tower () {
    # Ensure required role exist
    check_for_required_role swygue.ansible-tower
    # Load variables
    tower_variables
    update_tower_password

    #if [ ! -f "${tower_license}" ]
    #then
    #    printf "%s\n" " ${red}Could not find tower-license.txt under${end} ${yel}${project_dir}${end}"
    #    printf "%s\n" " ${blu}Please place file there and try again${end}"
    #    exit 1
    #else
    if [ -f "${tower_license}" ]
    then
        if ! grep -q eula_accepted "${tower_license}"
        then
            printf "%s\n" " Adding ${cyn}eula_accepted${end} to ${tower_license}"
            sed -i '/license_type/a \ \ \ \ "eula_accepted" : "true",' "${tower_license}"
        fi
    fi
    ansible-playbook "${TOWER_SERVER_PLAYBOOK}" || exit $?
}

function qubinode_deploy_tower () {
    printf "\n\n${yel}    ********************************${end}\n"
    printf "${yel}    *   Ansible Tower Deployment   *${end}\n"
    printf "${yel}    ********************************${end}\n\n"
    # Load variables
    tower_variables

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
    printf "\n\n ${cyn}********************************************************************${end}\n"
    printf " * The Tower server VM appears to be deployed and in good state *\n\n"
    printf "    Web Url: ${yel}${tower_webconsole}${end} \n"
    printf "    Username: ${blu}$(whoami)${end} \n"
    printf "    Password: ${blu}the vault variable${end} ${yel}admin_user_password${end} \n\n"
    printf " To view your password run the below command.\n"
    printf "       ${grn}ansible-vault view ${project_dir}/playbooks/vars/vault.yml${end} \n"
    printf " ${cyn}*******************************************************************************${end}\n\n"
}
