#!/bin/bash

# This is where we prompt users for answers to
# keys we have predefined. Any senstive data is
# collected using a different function
function ask_user_for_networking_info () {
    varsfile=$1
    qubinode_networking
}


function ask_for_vault_values () {
    vaultfile=$1
    varsfile=$2

    # decrypt ansible vault file
    decrypt_ansible_vault "${vaultfile}" >/dev/null


    # root user password to be set for virtual instances created
    if grep '""' "${vaultfile}"|grep -q admin_user_password
    then
        printf "%s\n" "   When entering the password, do not ${yel}Backspace${end}."
        printf "%s\n\n" "   Just ${yel}Ctrl-c${end} to cancel then run the installer again."
        unset admin_user_password
        printf "%s\n" ""
        printf "%s\n" "  ${yel}****************************************************************************${end}"
        printf "%s\n\n" "    ${cyn}        Passowrd Info${end}"
        printf "%s\n\n" "   Your username ${yel}${CURRENT_USER}${end} will be used to ssh into all the VMs created."
        printf "%s" "   Enter a password for ${yel}${CURRENT_USER}${end} ${grn}[ENTER]${end}: "
        read_sensitive_data
        printf "%s\n\n" ""
        admin_user_password="${sensitive_data}"
        sed -i "s/admin_user_password: \"\"/admin_user_password: "$admin_user_password"/g" "${vaultfile}"
        echo ""
    fi

    # encrypt ansible vault
    encrypt_ansible_vault "${vaultfile}" >/dev/null
}

function ask_user_input () {
    idm_server_ip=$(awk '/^idm_server_ip:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')
    user_input_complete=$(awk '/^user_input_complete:/ {print $2;exit}' "${project_dir}/playbooks/vars/all.yml" |tr -d '"')
    if [ "A${teardown}" != "Atrue" ]
    then 


        if [ "A${user_input_complete}" != "Ayes" ]
        then
            printf "\n\n" ""
            printf "%s\n" "   ${cyn}If you've made an mistake hit${end} ${yel}Ctrl-c${end} ${cyn}to exit the install.${end}"
            printf "%s\n\n" " ${cyn}  Then run the below command to reset the installation.${end}"
            printf "%s\n\n" "   ${grn}./qubinode-installer -m clean${end}"
            printf "%s\n" " ${cyn}  Running ${end}${yel}./qubinode-installer -m clean${end} ${cyn}removes all configuration data.${end}"
            printf "%s\n\n" "   ${cyn}This effectively resets the installation progress.${end}"
            ask_for_vault_values "${vault_vars_file}"
            ask_user_for_networking_info "${vars_file}"
            ask_user_for_idm_domain
            #ask_user_for_idm_password
            ask_user_for_custom_idm_server
            sed -i "s/^user_input_complete:.*/user_input_complete: yes/g" "${project_dir}/playbooks/vars/all.yml"
        fi
    fi
}
