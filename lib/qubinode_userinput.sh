#!/bin/bash

# This is where we prompt users for answers to
# keys we have predefined. Any senstive data is
# collected using a different function
function ask_user_for_networking_info () {
    varsfile=$1

    qubinode_networking

    printf "%s\n\n" "" 
    printf "%s\n" "  The installer deploys Red Hat IdM as a DNS server." 
    printf "%s\n\n" "  This requires a DNS domain, accept the default below or enter your own." 
    # ask user for DNS domain or use default
    if grep '""' "${varsfile}"|grep -q domain
    then
        read -p " ${mag}Enter your dns domain or press${end} ${yel}[ENTER]${end} ${mag}for the default${end} ${blu}[lab.example]: ${end}" domain
        domain=${domain:-lab.example}
        sed -i "s/domain: \"\"/domain: "$domain"/g" "${varsfile}"
        printf "%s\n\n" "" 
    fi

    #if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
    #then
        # ask user to enter a upstream dns server or default to 1.1.1.1
        if grep '""' "${varsfile}"|grep -q dns_forwarder
        then
            printf "%s\n\n" "" 
            printf "%s\n" "  By default the forwarder for external DNS queries are sent to 1.1.1.1." 
            printf "%s\n\n" "  If you would like to use a different upstream DNS server enter it below." 
            read -p " ${mag}Enter a upstream DNS server or press${end} ${yel}[ENTER]${end} ${mag}for the default${end} ${blue}[1.1.1.1]: ${end}" dns_forwarder
            dns_forwarder=${dns_forwarder:-1.1.1.1}
            sed -i "s/dns_forwarder: \"\"/dns_forwarder: "$dns_forwarder"/g" "${varsfile}"
        fi
    #fi
}

function ask_for_vault_values () {
    vaultfile=$1
    varsfile=$2

    # decrypt ansible vault file
    decrypt_ansible_vault "${vaultfile}" >/dev/null


    # root user password to be set for virtual instances created
    if grep '""' "${vaultfile}"|grep -q admin_user_password
    then
        unset admin_user_password
        printf "%s\n" ""
        printf "%s\n" "   Your username ${yel}${CURRENT_USER}${end} will be used to ssh into all the VMs created."
        printf "%s" "   Enter a password for ${yel}${CURRENT_USER}${end} ${grn}[ENTER]${end}: "
        read_sensitive_data
        admin_user_password="${sensitive_data}"
        sed -i "s/admin_user_password: \"\"/admin_user_password: "$admin_user_password"/g" "${vaultfile}"
        echo ""
    fi

    # encrypt ansible vault
    encrypt_ansible_vault "${vaultfile}" >/dev/null

    # Get RHSM credentials
    ask_user_for_rhsm_credentials
}

function ask_user_input () {
    idm_server_ip=$(awk '/idm_server_ip:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')
    idm_check_static_ip=$(awk '/idm_check_static_ip:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')
    if [ "A${teardown}" != "Atrue" ]
    then 
        printf "\n\n" ""
        printf "%s\n" " ${cyn}  If you've made an mistake you can restart the install by${end}"
        printf "%s\n" " ${cyn}  hitting ${end}${yel}Ctrl-c${end} ${cyn}then running ${end}${grn}./qubinode-installer -m clean${end}."
        printf "%s\n" "   When entering the password, do not ${yel}Backspace${end}."
        printf "%s\n\n" "   Just ${yel}Ctrl-c${end} to cancel then run the installer again."
        printf "%s\n" " ${cyn}  Running ${end}${yel}./qubinode-installer -m clean${end} ${cyn}removes all configuration data.${end}"
        printf "%s\n\n" "   ${cyn}This effectively resets the installation progress.${end}"
        ask_for_vault_values "${vault_vars_file}"
        ask_user_for_networking_info "${vars_file}"
        ask_user_for_idm_password
        ask_user_for_custom_idm_server
    fi
}
