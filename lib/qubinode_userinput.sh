#!/bin/bash

# This is where we prompt users for answers to
# keys we have predefined. Any senstive data is
# collected using a different function
function ask_user_for_networking_info () {
    varsfile=$1

    qubinode_networking
    # ask user for DNS domain or use default
    if grep '""' "${varsfile}"|grep -q domain
    then
        read -p " ${mag}Enter your dns domain or press${end} ${yel}[ENTER]${end} ${mag}for the default${end} ${blu}[lab.example]: ${end}" domain
        domain=${domain:-lab.example}
        sed -i "s/domain: \"\"/domain: "$domain"/g" "${varsfile}"
    fi

    # ask user to enter a upstream dns server or default to 1.1.1.1
    if grep '""' "${varsfile}"|grep -q dns_forwarder
    then
        read -p "${mag} Enter a upstream DNS server or press${end} ${yel}[ENTER]${end} ${mag}for the default${end} ${blue}[1.1.1.1]: ${end}" dns_forwarder
        dns_forwarder=${dns_forwarder:-1.1.1.1}
        sed -i "s/dns_forwarder: \"\"/dns_forwarder: "$dns_forwarder"/g" "${varsfile}"
    fi

    # ask user for their IP network and use the default
    if cat "${varsfile}"|grep -q changeme.in-addr.arpa
    then
        read -p " ${mag}Enter your IP Network or press${end} ${yel}[ENTER]${end} ${mag}for the default [$NETWORK]: ${end}" network
        network=${network:-"${NETWORK}"}
        PTR=$(echo "$NETWORK" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'|sed 's/0.//g')
        sed -i "s/changeme.in-addr.arpa/"$PTR"/g" "${varsfile}"
    fi
}

function ask_for_vault_values () {
    vaultfile=$1
    varsfile=$2

    # decrypt ansible vault file
    decrypt_ansible_vault "${vaultfile}"


    # root user password to be set for virtual instances created
    if grep '""' "${vaultfile}"|grep -q admin_user_password
    then
        unset admin_user_password
        printf "\n Your username ${yel}${CURRENT_USER}${end} will be used to ssh into all the VMs created.\n"
        print "%s\n" " Enter a password for ${yel}${CURRENT_USER}${end} ${grn}[ENTER]${end}: "
        read_sensitive_data
        admin_user_password="${sensitive_data}"
        sed -i "s/admin_user_password: \"\"/admin_user_password: "$admin_user_password"/g" "${vaultfile}"
        echo ""
    fi

    # encrypt ansible vault
    encrypt_ansible_vault "${vaultfile}"

    # Get RHSM credentials
    ask_user_for_rhsm_credentials
}

function ask_user_input () {
    if [ "A${teardown}" != "Atrue" ]
    then 
        printf "\n\n${yel}    ***************************${end}\n"
        printf "${yel}    *   Interactive Session   *${end}\n"
        printf "${yel}    ***************************${end}\n\n"


        #if [ "A${qubinode_maintenance_opt}" == "Ahost" ] || [ "A${maintenance}" == "Akvmhost" ]
        #then
            ask_user_if_qubinode_setup
        #fi

        ask_user_for_networking_info "${vars_file}"
        ask_for_vault_values "${vault_vars_file}"

        # IdM server input
        #if [ "A${idm_ask_already}" != "Ayes" ]
        #then
        #    if [ "A${deploy_idm_server}" == "Ayes" ]
        #    then
        #        ask_user_for_custom_idm_server
        #        qubinode_idm_ask_ip_address
        #        idm_ask_already=yes
        #    fi
        #fi
        ask_user_for_custom_idm_server
        ask_user_for_idm_password
    fi
}
