function display_idmsrv_unavailable () {
        echo ""
        echo ""
        echo ""
        echo "Eithr the IdM server variable idm_public_ip is not set."
        echo "Or the IdM server is not reachable."
        echo "Ensire the IdM server is running, update the variable and try again."
        exit 1
}

function qubinode_dns_manager () {
    prereqs
    option="$1"
    if [ ! -f "${project_dir}/inventory/hosts" ]
    then
        echo "${project_dir}/inventory/hosts is missing"
        echo "Please run quibinode-installer -m setup"
        echo ""
        exit 1
    fi

    if [ ! -f /usr/bin/ansible ]
    then
        echo "Ansible is not installed"
        echo "Please run qubinode-installer -m ansible"
        echo ""
        exit 1
    fi


    # Deploy IDM server
    IDM_PLAY="${project_dir}/playbooks/idm_server.yml"
    if [ "A${option}" == "Aserver" ]
    then
        if [ "A${teardown}" == "Atrue" ]
        then
            echo "Removing IdM server"
            ansible-playbook "${IDM_PLAY}" --extra-vars "vm_teardown=true" || exit $?
        else
            # Make sure IdM server is available
            IDM_SRV_IP=$(awk -F: '/idm_public_ip/ {print $2}' playbooks/vars/all.yml |        grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
            if [ "A${IDM_SRV_IP}" == "A" ]
            then
                display_idmsrv_unavailable
            elif [ "A${IDM_SRV_IP}" != "A" ]
            then
                if ping -c1 "${IDM_SRV_IP}" &> /dev/null
                then
                    echo "IdM server is appears to be up"
                else
                    echo "ping -c ${IDM_SRV_IP} FAILED"
                    display_idmsrv_unavailable
                fi
            fi
            echo "Install IdM server"
            ansible-playbook "${IDM_PLAY}" || exit $?
        fi
    fi

    #TODO: this block of code should be deleted
    # Add DNS records to IdM
    #if [ "A${option}" == "Arecords" ]
    #then
    #    ansible-playbook "${project_dir}/playbooks/add-idm-records.yml" || exit $?
    #fi
}

function qubinode_idm_user_input () {
    # Get static IP address for IDM
    if [ "${product_in_use}" == "idm" ]
    then
        confirm "Would you like to set a static IP for for the IdM server? Default choice is no. Yes/No"
        if [ "A${response}" == "Ayes" ]
        then
            if grep -q idm_server_ip "${vars_file}"
            then
                if grep idm_server_ip "${vars_file}"| grep -q '""'
                then
                    read -p "Enter an ip address for the IdM server: " USER_IDM_SERVER_IP
                    idm_server_ip="${USER_IDM_SERVER_IP}"
                    sed -i "s/idm_server_ip: \"\"/idm_server_ip: "$USER_IDM_SERVER_IP"/g" "${vars_file}"
                fi
            else
                echo "The variable idm_server_ip is not defined in ${vars_file}."
            fi

            if grep -q idm_server_ip "${vars_file}"
            then            
                if grep '""' "${vars_file}"|grep -q dns_server_public
                then
                    sed -i "s/dns_server_public: \"\"/dns_server_public: "$USER_IDM_SERVER_IP"/g" "${vars_file}"
                fi
            else
                echo "The variable idm_server_ip is not defined in ${vars_file}."
            fi
       fi
    fi
    exit
}