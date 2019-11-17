#!/bin/bash

setup_variables
IDM_VM_PLAY="${project_dir}/playbooks/idm_vm_deployment.yml"
product_in_use=idm
idm_vars_file="${project_dir}/playbooks/vars/idm.yml"
# Check if we should setup qubinode
DNS_SERVER_NAME=$(awk -F'-' '/idm_hostname:/ {print $2; exit}' "${idm_vars_file}" | tr -d '"')
prefix=$(awk '/instance_prefix/ {print $2;exit}' "${vars_file}")
suffix=$(awk -F '-' '/idm_hostname:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')
idm_srv_hostname="$prefix-$suffix"
idm_srv_fqdn="$prefix-$suffix.$domain"

function display_idmsrv_unavailable () {
        echo ""
        echo ""
        echo ""
        echo "Either the IdM server variable idm_public_ip is not set."
        echo "Or the IdM server is not reachable."
        echo "Ensire the IdM server is running, update the variable and try again."
        exit 1
}

# Ask if this host should be setup as a qubinode host
function ask_user_for_custom_idm_server () {
    #echo "asking for custom IdM"
    if [ "A${DNS_SERVER_NAME}" == "Anone" ]
    then
        echo "If you are not deploying an IdM server and instead plan on using an existing IdM server."
        echo "Choose yes to enter the hostname of your IdM server without the domain."
        echo "Otherwise choose no and the IdM server deployed by this installer will be used."
        echo ""
        echo ""
        confirm "Set custom IdM server hostname? yes/no"
        if [ "A${response}" == "Ayes" ]
        then
            read -p "Enter the hostname without the domain of your IdM server: " idm_server_hostname
            confirm "You entered $idm_server_hostname, is this correct? yes/no"
            if [ "A${response}" == "Ayes" ]
            then
                sed -i "s/idm_hostname:.*/idm_hostname: "$idm_server_hostname"/g" "${idm_vars_file}"
            else
                echo "Run the installer again"
                exit 1
            fi
        elif [ "A${response}" == "Ano" ]
        then
            echo "Setting default IdM server name"
            sed -i 's/idm_hostname:.*/idm_hostname: "{{ instance_prefix }}-dns01"/g' "${idm_vars_file}"
        else
            echo "No action taken"
        fi
    fi
}

function set_idm_static_ip () {
    read -p "Enter an ip address for the IdM server: " USER_IDM_SERVER_IP
    idm_server_ip="${USER_IDM_SERVER_IP}"
    sed -i "s/idm_server_ip:.*/idm_server_ip: "$USER_IDM_SERVER_IP"/g" "${idm_vars_file}"
    echo "IdM server VM will install using this ip address $idm_server_ip"
}

function qubinode_idm_ask_ip_address () {
    IDM_STATIC=$(awk '/idm_check_static_ip/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')
    CURRENT_IDM_IP=$(awk '/idm_server_ip:/ {print $2}' "${idm_vars_file}")
    echo "${IDM_STATIC}" | grep -qE 'yes|no'
    RESULT=$?
    if [ "A${RESULT}" == "A1" ]
    then
        echo "Would you like to set a static IP for for the IdM server?"
        echo "Default choice is to choose: No"
        confirm " Yes/No"
        if [ "A${response}" == "Ayes" ]
        then
            sed -i "s/idm_check_static_ip:.*/idm_check_static_ip: yes/g" ${idm_vars_file}
        else
            sed -i "s/idm_check_static_ip:.*/idm_check_static_ip: yes/g" ${idm_vars_file}
        fi
    fi

    # Check on vailable IP
    IDM_STATIC=$(awk '/idm_check_static_ip/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')
    MSGUK="The varaible idm_server_ip in $idm_vars_file is set to an unknown value of $CURRENT_IDM_IP"
        
    if [ "A${IDM_STATIC}" == "Ayes" ]
    then
        if [ "A${CURRENT_IDM_IP}" == 'A""' ]
        then
           set_idm_static_ip
        elif [ "A${CURRENT_IDM_IP}" != 'A""' ]
        then
            echo "IdM server ip address is set to ${CURRENT_IDM_IP}"
            confirm "Do you want to change? yes/no"
            if [ "A${response}" == "Ayes" ]
            then
                set_idm_static_ip
            fi
        else
            echo "${MSGUK}"
            echo 'Please reset to "" and try again'
            exit 1
        fi
    fi
}



function isIdMrunning () {
   if ! curl -k -s "https://${idm_srv_fqdn}/ipa/config/ca.crt" > /dev/null
   then
       idm_running=false
   elif curl -k -s "https://${idm_srv_fqdn}/ipa/config/ca.crt" > /dev/null
   then
       idm_running=true
   else
       idm_running=false
   fi
}

function qubinode_teardown_idm () {
    IDM_PLAY_CLEANUP="${project_dir}/playbooks/idm_server_cleanup.yml"
    if sudo virsh list --all |grep -q "${idm_srv_hostname}"
    then
        echo "Remove IdM VM"
        ansible-playbook "${IDM_VM_PLAY}" --extra-vars "vm_teardown=true" || exit $?
    fi
    echo "Ensure IdM server deployment is cleaned up"
    ansible-playbook "${IDM_PLAY_CLEANUP}" || exit $?

    printf "\n\n*************************\n"
    printf "* IdM server VM deleted *\n"
    printf "*************************\n\n"
}

function qubinode_deploy_idm_vm () {
   qubinode_vm_deployment_precheck
   isIdMrunning
   IDM_PLAY_CLEANUP="${project_dir}/playbooks/idm_server_cleanup.yml"
   SET_IDM_STATIC_IP=$(awk '/idm_check_static_ip/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')

   if [ "A${idm_running}" == "Afalse" ]
   then
       echo "running playbook ${IDM_VM_PLAY}"
       if [ "A${SET_IDM_STATIC_IP}" == "Ayes" ]
       then
           echo "Deploy with custom IP"
           idm_server_ip=$(awk '/idm_server_ip:/ {print $2}' "${idm_vars_file}")
           ansible-playbook "${IDM_VM_PLAY}" --extra-vars "vm_ipaddress=${idm_server_ip}"|| exit $?
        else
            echo "Deploy without custom IP"
            ansible-playbook "${IDM_VM_PLAY}" || exit $?
        fi
    fi
}

function qubinode_install_idm () {
   qubinode_vm_deployment_precheck
   ask_user_input
   IDM_INSTALL_PLAY="${project_dir}/playbooks/idm_server.yml"

   echo "Install and configure the IdM server"
   idm_server_ip=$(awk '/idm_server_ip:/ {print $2}' "${idm_vars_file}")
   ansible-playbook "${IDM_INSTALL_PLAY}" --extra-vars "vm_ipaddress=${idm_server_ip}" || exit $?
   isIdMrunning
   if [ "A${idm_running}" == "Atrue" ]
   then
     printf "\n\n*********************************************************************************\n"
     printf "    **IdM server is installed**\n"
     printf "         Url: https://${idm_srv_fqdn}/ipa \n"
     printf "         Username: $(whoami) \n"
     printf "         Password: the vault variable *admin_user_password* \n\n"
     printf "Run: ansible-vault edit ${project_dir}/playbooks/vars/vault.yml \n"
     printf "*******************************************************************************\n\n"
   fi
}

function qubinode_deploy_idm () {
    qubinode_deploy_idm_vm
    qubinode_install_idm
}
