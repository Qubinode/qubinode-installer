#!/bin/bash

# This is where we prompt users for answers to
# keys we have predefined. Any senstive data is
# collected using a different function
function ask_user_for_networking_info () {
    varsfile=$1

    # ask user for DNS domain or use default
    if grep '""' "${varsfile}"|grep -q domain
    then
        read -p "Enter your dns domain or press [ENTER] for the default [lab.example]: " domain
        domain=${domain:-lab.example}
        sed -i "s/domain: \"\"/domain: "$domain"/g" "${varsfile}"
    fi

    # ask user for public DNS server or use default
    if grep '""' "${varsfile}"|grep -q dns_server_public
    then
        read -p "Enter a upstream DNS server or press [ENTER] for the default [1.1.1.1]: " dns_server_public
        dns_server_public=${dns_server_public:-1.1.1.1}
        sed -i "s/dns_server_public: \"\"/dns_server_public: "$dns_server_public"/g" "${varsfile}"
    fi

    # ask user for their IP network and use the default
    if cat "${varsfile}"|grep -q changeme.in-addr.arpa
    then
        read -p "Enter your IP Network or press [ENTER] for the default [$NETWORK]: " network
        network=${network:-"${NETWORK}"}
        PTR=$(echo "$NETWORK" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'|sed 's/0.//g')
        sed -i "s/changeme.in-addr.arpa/"$PTR"/g" "${varsfile}"
    fi

    # # ask user to choose which libvirt network to use
    # if grep '""' "${varsfile}"|grep -q vm_libvirt_net
    # then
    #     declare -a networks=()
    #     mapfile -t networks < <(sudo virsh net-list --name|sed '/^[[:space:]]*$/d')
    #     createmenu "${networks[@]}"
    #     network=($(echo "${selected_option}"))
    #     sed -i "s/vm_libvirt_net: \"\"/vm_libvirt_net: "$network"/g" "${varsfile}"
    # fi
}

function ask_for_vault_values () {
    vaultfile=$1
    varsfile=$2

    # decrypt ansible vault file
    decrypt_ansible_vault "${vaultfile}"

    # Generate a ramdom password for IDM directory manager
    # This will not prompt the user
    if grep '""' "${vaultfile}"|grep -q idm_dm_pwd
    then
        idm_dm_pwd=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
        sed -i "s/idm_dm_pwd: \"\"/idm_dm_pwd: "$idm_dm_pwd"/g" "${vaultfile}"
    fi

    # root user password to be set for virtual instances created
    if grep '""' "${vaultfile}"|grep -q admin_user_password
    then
        unset admin_user_password
        echo "Your username ${CURRENT_USER} will be used to ssh into all the VMs created."
        echo -n "Enter a password for ${CURRENT_USER} [ENTER]: "
        read_sensitive_data
        admin_user_password="${sensitive_data}"
        sed -i "s/admin_user_password: \"\"/admin_user_password: "$admin_user_password"/g" "${vaultfile}"
        echo ""
    fi

    # This is the password used to log into the IDM server webconsole and also the admin user
    if grep '""' "${vaultfile}"|grep -q idm_admin_pwd
    then
        unset idm_admin_pwd
        while [[ ${#idm_admin_pwd} -lt 8 ]]
        do
            echo -n 'Enter a password for the IDM server console and press [ENTER]: '
            read_sensitive_data
            idm_admin_pwd="${sensitive_data}"
            if [ ${#idm_admin_pwd} -lt 8 ]
            then
                echo "Important: Password must be at least 8 characters long."
                echo "Password must be at least 8 characters long"
                echo "Please re-run the installer"
            fi
        done
        sed -i "s/idm_admin_pwd: \"\"/idm_admin_pwd: "$idm_admin_pwd"/g" "${vaultfile}"
        echo ""
        #fi
    fi

    if grep '""' "${vars_file}"|grep -q rhsm_reg_method
    then
        echo ""
        echo "Which option are you using to register the system? : "
        rhsm_msg=("Activation Key" "Username and Password")
        createmenu "${rhsm_msg[@]}"
        rhsm_reg_method=($(echo "${selected_option}"))
        sed -i "s/rhsm_reg_method: \"\"/rhsm_reg_method: "$rhsm_reg_method"/g" "${vars_file}"
        if [ "A${rhsm_reg_method}" == "AUsername" ];
        then
            echo ""
            decrypt_ansible_vault "${vault_vars_file}"
            get_rhsm_user_and_pass
            encrypt_ansible_vault "${vault_vars_file}"
        elif [ "A${rhsm_reg_method}" == "AActivation" ];
        then
            if grep '""' "${vault_vars_file}"|grep -q rhsm_username
            then
                echo ""
                echo "We still need to get your RHSM username and password."
                echo "We need this to pull containers for OpenShift Platform Installation."
                echo ""
                decrypt_ansible_vault "${vault_vars_file}"
                get_rhsm_user_and_pass
                encrypt_ansible_vault "${vault_vars_file}"
                echo ""
            fi

            if grep '""' "${vault_vars_file}"|grep -q rhsm_activationkey
            then
                echo -n "Enter your RHSM activation key and press [ENTER]: "
                read rhsm_activationkey
                unset rhsm_org
                sed -i "s/rhsm_activationkey: \"\"/rhsm_activationkey: "$rhsm_activationkey"/g" "${vaultfile}"
            fi
            if grep '""' "${vault_vars_file}"|grep -q rhsm_org
            then
                echo -n 'Enter your RHSM ORG ID and press [ENTER]: '
                read_sensitive_data
                rhsm_org="${sensitive_data}"
                sed -i "s/rhsm_org: \"\"/rhsm_org: "$rhsm_org"/g" "${vaultfile}"
                echo ""
            fi
        fi
    elif grep '""' "${vaultfile}"|grep -q rhsm_username
    then
        echo ""
        decrypt_ansible_vault "${vault_vars_file}"
        get_rhsm_user_and_pass
        encrypt_ansible_vault "${vault_vars_file}"
    else
        echo "Credentials for RHSM is already collected."
    fi

    # encrypt ansible vault
    encrypt_ansible_vault "${vaultfile}"
}

function ask_user_input () {
    echo ""
    echo ""
    ask_user_for_networking_info "${vars_file}"
    ask_for_vault_values "${vault_vars_file}"
    if [ "A${product_in_use}" == "Aidm" ]
    then
        qubinode_idm_user_input
    fi
}
