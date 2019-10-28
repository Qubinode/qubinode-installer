#!/bin/bash

IDM_VM_PLAY="${project_dir}/playbooks/idm_vm_deployment.yml"
product_in_use=idm
idm_vars_file="${project_dir}/playbooks/vars/idm.yml"
# Check if we should setup qubinode
DNS_SERVER_NAME=$(awk -F'-' '/idm_hostname:/ {print $2; exit}' "${idm_vars_file}" | tr -d '"')

function display_idmsrv_unavailable () {
        echo ""
        echo ""
        echo ""
        echo "Eithr the IdM server variable idm_public_ip is not set."
        echo "Or the IdM server is not reachable."
        echo "Ensire the IdM server is running, update the variable and try again."
        exit 1
}

# Ask if this host should be setup as a qubinode host
function ask_user_for_custom_idm_server () {
    #echo "asking for custom IdM"
    setup_variables
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


function qubinode_idm_ask_ip_address () {
    # Get static IP address for IDM
    if [ "${product_in_use}" == "idm" ]
    then
        IDM_STATIC=$(awk '/idm_check_static_ip/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')
        if [[ "A${IDM_STATIC}" == "A" ]] || [[ "A${IDM_STATIC}" == 'A""' ]]
        then
            confirm "Would you like to set a static IP for for the IdM server? Default choice is no. Yes/No"
            if [ "A${response}" == "Ayes" ]
            then
                sed -i "s/idm_check_static_ip:.*/idm_check_static_ip: yes/g" "${idm_vars_file}"
                if grep -q idm_server_ip "${idm_vars_file}"
                then
                    if grep idm_server_ip "${idm_vars_file}"| grep -q '""'
                    then
                        read -p "Enter an ip address for the IdM server: " USER_IDM_SERVER_IP
                        idm_server_ip="${USER_IDM_SERVER_IP}"
                        sed -i "s/idm_server_ip:.*/idm_server_ip: "$USER_IDM_SERVER_IP"/g" "${idm_vars_file}"
                    fi
                else
                    echo "The variable idm_server_ip is not defined in ${idm_vars_file}."
                fi
    
                #if grep -q idm_server_ip "${idm_vars_file}"
                #then            
                #    if grep '""' "${idm_vars_file}"|grep -q dns_server_public
                #    then
                #        sed -i "s/dns_server_public: \"\"/dns_server_public: "$USER_IDM_SERVER_IP"/g" "${idm_vars_file}"
                #    fi
                #else
                #    echo "The variable idm_server_ip is not defined in ${idm_vars_file}."
                #fi
            elif [ "A${response}" == "Ano" ]
            then
                sed -i "s/idm_check_static_ip:.*/idm_check_static_ip: no/g" "${idm_vars_file}"
            else
                echo "IdM static ip check not required"
            fi
        fi
    fi
}


function isIdMrunning () {
   setup_variables
   prefix=$(awk '/instance_prefix/ {print $2;exit}' "${vars_file}")
   suffix=$(awk -F '-' '/idm_hostname:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')
   idm_srv_hostname="$prefix-$suffix"
   idm_srv_fqdn="$prefix-$suffix.$domain"
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
    qubinode_vm_deployment_precheck
    isIdMrunning
    IDM_PLAY_CLEANUP="${project_dir}/playbooks/idm_server_cleanup.yml"

    if sudo virsh list |grep -q "${idm_srv_hostname}"
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
       echo "Deploy IdM VM"
       if [ "A${SET_IDM_STATIC_IP}" == "Ayes" ]
       then
           idm_server_ip=$(awk '/idm_server_ip/ {print $2}' "${idm_vars_file}")
           echo "Deploy with custom IP"
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
   isIdMrunning
   IDM_INSTALL_PLAY="${project_dir}/playbooks/idm_server.yml"

   if [ "A${idm_running}" == "Afalse" ]
   then
       echo "Install and configure the IdM server"
       ansible-playbook "${IDM_INSTALL_PLAY}" || exit $?
   fi
}

function qubinode_deploy_idm () {
    qubinode_deploy_idm_vm
#    qubinode_install_idm
}
