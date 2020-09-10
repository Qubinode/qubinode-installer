#!/bin/bash

setup_variables
IDM_VM_PLAY="${project_dir}/playbooks/idm_vm_deployment.yml"
product_in_use=idm
idm_vars_file="${project_dir}/playbooks/vars/idm.yml"
# Check if we should setup qubinode
DNS_SERVER_NAME=$(awk -F'-' '/idm_hostname:/ {print $2; exit}' "${idm_vars_file}" | tr -d '"')
prefix=$(awk '/instance_prefix:/ {print $2;exit}' "${vars_file}")
idm_server_name=$(awk '/idm_server_name:/ {print $2;exit}' "${vars_file}")
suffix=$(awk '/idm_server_name:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')
idm_srv_hostname="$prefix-$suffix"
idm_srv_fqdn="$prefix-$suffix.$domain"
idm_server_ip=$(awk '/idm_server_ip:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')
idm_admin_user=$(awk '/idm_admin_user:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')

# Set the VM OS release to match the host system
sed -i "s/^rhel_major:.*/rhel_major: $rhel_major/g" $idm_vars_file

function display_idmsrv_unavailable () {
    printf "%s\n" "${yel}Either the IdM server variable idm_public_ip is not set.${end}"
    printf "%s\n" "${yel}Or the IdM server is not reachable.${end}"
    printf "%s\n" "${yel}Ensure the IdM server is running, update the variable and try again.${end}"
    exit 1
}

function ask_user_for_idm_domain () {

    # ask user for DNS domain or use default
    if grep '""' "${varsfile}"|grep -q domain
    then
        printf "%s\n\n" ""
        printf "%s\n" "  ${yel}****************************************************************************${end}"
        printf "%s\n\n" "    ${cyn}        Red Hat Identity Manager (IdM)${end}"
        printf "%s\n" "   The installer deploys Red Hat IdM as a DNS server."
        printf "%s\n\n" "   This requires a DNS domain, accept the default below or enter your own."

        read -p "   ${blu}Enter your dns domain or press${end} ${yel}[ENTER]${end} ${mag}for the default${end} ${blu}[lab.example]: ${end}" domain
        domain=${domain:-lab.example}
        sed -i "s/domain: \"\"/domain: "$domain"/g" "${varsfile}"
        printf "%s\n" ""
    fi

    # ask user to enter a upstream dns server or default to 1.1.1.1
    if grep '""' "${varsfile}"|grep -q dns_forwarder
    then
        printf "%s\n\n" ""
        printf "%s\n" "   By default the forwarder for external DNS queries are sent to 1.1.1.1."
        printf "%s\n\n" "   If you would like to use a different upstream DNS server enter it below."
        read -p "   ${blu}Enter an upstream DNS server or press${end} ${yel}[ENTER]${end} ${mag}for the default${end} ${blue}[1.1.1.1]: ${end}" dns_forwarder
        dns_forwarder=${dns_forwarder:-1.1.1.1}
        sed -i "s/dns_forwarder: \"\"/dns_forwarder: "$dns_forwarder"/g" "${varsfile}"
    fi
}

function ask_user_for_idm_password () {
    # This is the password used to log into the IDM server webconsole and also the admin user
    #if grep '""' "${vaultfile}"|grep -q idm_admin_pwd
    idm_admin_pwd=$(ansible-vault view ${vaultfile}|awk '/idm_admin_pwd:/ {print $2;exit}')
    if [ "A${idm_admin_pwd}" == 'A""' ];
    then
        unset idm_admin_pwd
        while [[ ${#idm_admin_pwd} -lt 8 ]]
        do
            printf "%s\n" ""
            printf "%s\n\n" "   Your username ${yel}${CURRENT_USER}${end} will be use as the admin user."
            printf "%s" "   ${blu}Enter a password to be set for the IdM admin user and press${end} ${grn}[ENTER]${end}: "
            read_sensitive_data
            idm_admin_pwd="${sensitive_data}"
            if [ ${#idm_admin_pwd} -lt 8 ]
            then
                printf "%s\n" ""
                printf "%s\n\n" "    ${red}**IMPORTANT**${end}"
                printf "%s\n" "  The password must be at least ${yel}8${end} characters long."
            fi
        done
        decrypt_ansible_vault "${vaultfile}" > /dev/null
        sed -i "s/idm_admin_pwd: \"\"/idm_admin_pwd: "$idm_admin_pwd"/g" "${vaultfile}"
        echo ""
    fi

    # encrypt ansible vault
    encrypt_ansible_vault "${vaultfile}" > /dev/null

    # Generate a ramdom password for IDM directory manager
    # This will not prompt the user
    if grep '""' "${vaultfile}"|grep -q idm_dm_pwd
    then
        idm_dm_pwd=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
        sed -i "s/idm_dm_pwd: \"\"/idm_dm_pwd: "$idm_dm_pwd"/g" "${vaultfile}"
    fi
}

function ask_user_for_custom_idm_server () {
    deploy_idm_server=$(awk '/deploy_idm_server:/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')
    ask_use_existing_idm=$(awk '/ask_use_existing_idm:/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')

    # Ask if this host should be setup as a qubinode host
    if [ "A${ask_use_existing_idm}" == 'Ayes' ]
    then
        printf "%s\n" "  ${cyn}IdM Server Deployment Options${end}"
        printf "%s\n\n" "  ${cyn}*********************************${end}"
        printf "%s\n" "  The Qubinode depends on IdM as the DNS server."
        printf "%s\n" "  To provide DNS resolutions for the services deployed."
        printf "%s\n" "  The installer default action is deploy a local IdM server."
        printf "%s\n\n" "  You can also choose to use an existing IdM server."

        confirm " ${blu} Would you like to use an existing IdM server?${end} ${yel}yes/no${end}"
        if [ "A${response}" == "Ayes" ]
        then
            static_ip_msg=" Enter the ip address for the existing IdM server"
            static_ip_result_msg=" The qubinode-installer will connect to the IdM server on"
            set_idm_static_ip
            sed -i "s/1.1.1.1/$idm_server_ip/g" ${project_dir}/playbooks/vars/*.yml

            printf "%s\n\n" ""
            printf "%s\n" "  Please provide the hostname of the existing DNS server."
            printf "%s\n\n" "  For example if you IdM server is ${yel}dns01.lab.com${end}, you should enter ${yel}dns01${end}."
            read -p "  ${blu}What is the hostname of the existing DNS server?${end} " IDM_NAME
            idm_hostname="${IDM_NAME}"
            confirm "  You entered $idm_hostname, is this correct? ${yel}yes/no${end}"
            if [ "A${response}" == "Ayes" ]
            then
                sed -i "s/idm_hostname:.*/idm_hostname: "$idm_hostname"/g" "${idm_vars_file}"
                printf "%s\n" ""
                printf "%s\n" "  ${blu}Your IdM server hostname is set to${end} ${yel}$idm_hostname${end}"
            fi

            printf "%s\n\n" ""
            read -p "  What is the your existing IdM server admin username? " IDM_USER
            idm_admin_user=$IDM_USER
            confirm "  You entered $idm_admin_user, is this correct? ${yel}yes/no${end}"
            if [ "A${response}" == "Ayes" ]
            then
                sed -i "s/idm_admin_user:.*/idm_admin_user: "$idm_admin_user"/g" "${idm_vars_file}"
                printf "%s\n" ""
            fi
            sed -i "s/ask_use_existing_idm:.*/ask_use_existing_idm: skip/g" "${idm_vars_file}"

            # Ask user for password for IdM
            ask_user_for_idm_password
        else
            # Ask user for password for IdM
            ask_user_for_idm_password

            # ensure user isn't prompted for existing IdM
            sed -i "s/ask_use_existing_idm:.*/ask_use_existing_idm: skip/g" "${idm_vars_file}"

            # Ask user if they want to give the IdM server a static IP
            if grep '""' "${idm_vars_file}"|grep -q "idm_check_static_ip:"
            then
                printf "%s\n" ""
                printf "%s\n" "  The IdM server will be assigned a dynamic ip address from"
                printf "%s\n\n" "  your network. You can assign a static ip address instead."
                confirm "  ${blu}Would you like to assign a static ip address to the IdM server?${end} ${yel}yes/no${end}"
                if [ "A${response}" == "Ayes" ]
                then
                    static_ip_msg=" Enter the ip address you would like to assign to the IdM server"
                    static_ip_result_msg=" The qubinode-installer will connect to the IdM server on"
                    set_idm_static_ip
                fi
            fi

            printf "%s\n" ""
            printf "%s\n" "  You can safely choose no for this next question."
            printf "%s\n" "  Choose yes if you need to use a existing DNS domain."
            confirm "  ${blu}Would you like to enable allow-zone-overlap? yes/no${end}"
            if [ "A${response}" == "Ayes" ]
            then
                sed -i "s/idm_zone_overlap:.*/idm_zone_overlap: true/g" "${idm_vars_file}"
                printf "%s\n" ""
            fi

            # Tell installer to deploy IdM server
            sed -i "s/deploy_idm_server:.*/deploy_idm_server: yes/g" "${idm_vars_file}"

            # Setting default IdM server name
            #sed -i 's/idm_hostname:.*/idm_hostname: "{{ instance_prefix }}-${idm_server_name}"/g' "${idm_vars_file}"

            # Setting default IdM server name
            CHANGE_PTR=$(cat ${project_dir}/playbooks/vars/all.yml | grep qubinode_ptr: | awk '{print $2}')
            sed -i 's#  - "{{ qubinode_ptr }}"#  - '$CHANGE_PTR'#g'  "${idm_vars_file}"
        fi
    fi

    # ask user for DNS domain or use default
    if grep '""' "${vars_file}"|grep -q domain
    then
        read -p " ${blu}Enter your dns domain or press${end} ${yel}[ENTER]${end}: " domain
        domain=${domain:-lab.example}
        confirm "  You entered ${yel}$domain${end}, is this correct?${yel}yes/no${end}"
        if [ "A${response}" == "Ayes" ]
        then
            sed -i "s/domain: \"\"/domain: "$domain"/g" "${varsfile}"
        fi
    fi
    #TODO:
    # - ping the dns server to ensure it is up
    #- update {{ idm_server_ip | default('1.1.1.1') }} to point to the dns ip provided

    # Check for required flags set file to skip this function if all is present
    if [[ -f ${vaultfile} ]] && [[ -f /usr/bin/ansible-vault ]]
    then
        idm_ssh_user='""'
        idm_dm_pwd='""'
        idm_admin_pwd='""'
        if ansible-vault view "${vaultfile}" > /dev/null 2>&1
        then
            idm_ssh_user=$(ansible-vault view ${vaultfile}|awk '/idm_ssh_user:/ {print $2;exit}')
            idm_dm_pwd=$(ansible-vault view ${vaultfile}|awk '/idm_dm_pwd:/ {print $2;exit}')
            idm_admin_pwd=$(ansible-vault view ${vaultfile}|awk '/idm_admin_pwd:/ {print $2;exit}')
        else
            idm_ssh_user=$(awk '/idm_ssh_user:/ {print $2;exit}' ${vaultfile})
            idm_dm_pwd=$(awk '/idm_dm_pwd:/ {print $2;exit}' ${vaultfile})
            idm_admin_pwd=$(awk '/idm_admin_pwd:/ {print $2;exit}' ${vaultfile})
        fi

        if [[ "A${idm_ssh_user}" != 'A""' ]] && [[ "A${idm_dm_pwd}" != 'A""' ]] && [[ "A${idm_admin_pwd}" != 'A""' ]]
        then
            # Tell installer not to deploy IdM server
            sed -i "s/ask_use_existing_idm:.*/ask_use_existing_idm: skip/g" "${idm_vars_file}"
        fi
    fi
}


function set_idm_static_ip () {
    printf "%s\n" ""
    read -p " ${blu}$static_ip_msg:${end} " USER_IDM_SERVER_IP
    idm_server_ip="${USER_IDM_SERVER_IP}"
    confirm "  You entered ${yel}$idm_server_ip${end}, is this correct? ${yel}yes/no${end}"
    if [ "A${response}" == "Ayes" ]
    then
        sed -i "s/idm_server_ip:.*/idm_server_ip: "$USER_IDM_SERVER_IP"/g" "${idm_vars_file}"
        sed -i "s/idm_check_static_ip:.*/idm_check_static_ip: no/g" ${idm_vars_file}
        printf "%s\n\n" ""
        printf "%s\n\n" " $static_ip_result_msg ${yel}$idm_server_ip${end}"
    fi
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
            sed -i "s/idm_check_static_ip:.*/idm_check_static_ip: no/g" ${idm_vars_file}
        fi
    fi

    # Check on vailable IP
    IDM_STATIC=$(awk '/idm_check_static_ip/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')
    MSGUK="The varaible idm_server_ip in $idm_vars_file is set to an unknown value of $CURRENT_IDM_IP"

    if ! curl -k -s "https://${idm_srv_fqdn}/ipa/config/ca.crt" > /dev/null
    then
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
     fi
}



function isIdMrunning () {
     # Test idm server 
    prefix=$(awk '/instance_prefix:/ {print $2;exit}' "${vars_file}")
    suffix=$(awk '/idm_server_name:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')
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
     IDM_PLAY_CLEANUP="${project_dir}/playbooks/idm_server_cleanup.yml"
     libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/playbooks/vars/kvm_host.yml")
     local vmdisk="${libvirt_dir}/${idm_srv_hostname}_vda.qcow2"
     if sudo virsh list --all |grep -q "${idm_srv_hostname}"
     then
         echo "Remove IdM VM"
         ansible-playbook "${IDM_VM_PLAY}" --extra-vars "vm_teardown=true" || exit $?
     fi
     echo "Ensure IdM server deployment is cleaned up"
     ansible-playbook "${IDM_PLAY_CLEANUP}" || exit $?
     sudo test -f "${vmdisk}" && sudo rm -f "${vmdisk}"

     printf "\n\n*************************\n"
     printf "* IdM server VM deleted *\n"
     printf "*************************\n\n"
}

function qubinode_deploy_idm_vm () {
    if grep deploy_idm_server "${idm_vars_file}" | grep -q yes
    then
        isIdMrunning
        if [ "A${idm_running}" == "Afalse" ]
        then
            qubinode_setup
        fi

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
     fi
}

function qubinode_idm_status () {
    isIdMrunning
    if [ "A${idm_running}" == "Atrue" ]
    then
        printf "\n\n\n"
        printf "     ${blu}IdM server is installed${end}\n"
        printf "   ${yel}****************************************************${end}\n"
        printf "    Webconsole: ${cyn}https://${idm_srv_fqdn}/ipa/ui/${end} \n"
        printf "    IP Address: ${cyn}${idm_server_ip}${end} \n"
        printf "    Username: ${cyn}${idm_admin_user}${end}\n"
        printf "    Password: the vault variable ${cyn}admin_user_password${end} \n\n"
        printf "    ${blu}Run:${end} ${grn}ansible-vault edit ${vaultfile}${end} \n\n"
     else
        printf "%s\n" " ${red}IDM Server was not properly deployed please verify deployment.${end}"
        exit 1
     fi
}

function qubinode_install_idm () {
    isIdMrunning
    if [ "A${idm_running}" != "Atrue" ]
    then
        ask_user_input
        IDM_INSTALL_PLAY="${project_dir}/playbooks/idm_server.yml"

        echo "Install and configure the IdM server"
        idm_server_ip=$(awk '/idm_server_ip:/ {print $2}' "${idm_vars_file}")
        echo "Current IP of IDM Server ${idm_server_ip}" || exit $?
        ansible-playbook "${IDM_INSTALL_PLAY}" --extra-vars "vm_ipaddress=${idm_server_ip}" || exit $?
	qubinode_idm_status
     else
	qubinode_idm_status
     fi
}

function qubinode_deploy_idm () {
    check_additional_storage

    # Ensure host system is setup as a KVM host
    kvm_host_health_check
    if [[ "A${KVM_IN_GOOD_HEALTH}" != "Aready"  ]]; then
      qubinode_setup_kvm_host
    fi

    qubinode_deploy_idm_vm
    qubinode_install_idm
}

function qubinode_idm_maintenance () {
    case ${product_maintenance} in
       stop)
            name=$idm_srv_hostname
	    qubinode_rhel_maintenance
            ;;
       start)
            name=$idm_srv_hostname
	    qubinode_rhel_maintenance
            ;;
       status)
            qubinode_idm_status
            ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}

