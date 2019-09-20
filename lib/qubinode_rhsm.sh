#!/bin/bash

# This function checks the status of RHSM registration

# This function checks the status of RHSM registration
function check_rhsm_status () {
    if grep Fedora /etc/redhat-release
    then
        echo "Skipping checking RHSM status"
    else
        sudo subscription-manager identity > /dev/null 2>&1
        RESULT="$?"
        if [ "A${RESULT}" == "A1" ]
        then
            echo "This system is not yet registered"
            echo "Please run qubinode-installer -m rhsm"
            echo ""
            exit 1
        fi

        status_result=$(mktemp)
        sudo subscription-manager status > "${status_result}" 2>&1
        status=$(awk -F: '/Overall Status:/ {print $2}' "${status_result}"|sed 's/^ *//g')
        if [ "A${status}" != "ACurrent" ]
        then
            sudo subscription-manager refresh
            sudo subscription-manager attach --auto
        fi

        #check again
        sudo subscription-manager status > "${status_result}" 2>&1
        status=$(awk -F: '/Overall Status:/ {print $2}' "${status_result}"|sed 's/^ *//g')
        if [ "A${status}" != "ACurrent" ]
        then
            echo "Cannot resolved $(hostname) subscription status"
            echo "Error details are: "
            cat "${status_result}"
            echo ""
            echo "Please resolved and try again"
            echo ""
            exit 1
        fi
    fi
}

# this function checks if the system is registered to RHSM
# validate the registration or register the system
# if it's not registered
function qubinode_rhsm_register () {
    if grep Fedora /etc/redhat-release
    then
        echo "Skipping registering to RHSM"
    else
        prereqs
        vaultfile="${vault_vars_file}"
        varsfile="${vars_file}"
        does_exist=$(does_file_exist "${vault_vars_file} ${vars_file}")
        if [ "A${does_exist}" == "Ano" ]
        then
            echo "The file ${vars_file} and ${vault_vars_file} does not exist"
            echo ""
            echo "Try running: qubinode-installer -m setup"
            echo ""
            exit 1
        fi
    
        RHEL_RELEASE=$(awk '/rhel_release/ {print $2}' "${vars_file}" |grep [0-9])
        IS_REGISTERED_tmp=$(mktemp)
        sudo subscription-manager identity > "${IS_REGISTERED_tmp}" 2>&1
    
        # decrypt ansible vault
        decrypt_ansible_vault "${vault_vars_file}"
    
        # Gather subscription infomration
        rhsm_reg_method=$(awk '/rhsm_reg_method/ {print $2}' "${vars_file}")
        if [ "A${rhsm_reg_method}" == "AUsername" ]
        then
            rhsm_msg="Registering system to rhsm using your username/password"
            rhsm_username=$(awk '/rhsm_username/ {print $2}' "${vaultfile}")
            rhsm_password=$(awk '/rhsm_password/ {print $2}' "${vaultfile}")
            rhsm_cmd_opts="--username='${rhsm_username}' --password='${rhsm_password}'"
        elif [ "A${rhsm_reg_method}" == "AActivation" ]
        then
            rhsm_msg="Registering system to rhsm using your activaiton key"
            rhsm_org=$(awk '/rhsm_org/ {print $2}' "${vaultfile}")
            rhsm_activationkey=$(awk '/rhsm_activationkey/ {print $2}' "${vaultfile}")
            rhsm_cmd_opts="--org='${rhsm_org}' --activationkey='${rhsm_activationkey}'"
        else
            echo "The value of rhsm_reg_method in "${vars_file}" is not a valid value."
            echo "Valid options are 'Activation' or 'Username'."
            echo ""
            echo "Try running: qubinode-installer -m setup"
            echo ""
            exit 1
        fi
    
        #encrupt vault file
        encrypt_ansible_vault "${vault_vars_file}"
    
        IS_REGISTERED=$(grep -o 'This system is not yet registered' "${IS_REGISTERED_tmp}")
        if [ "A${IS_REGISTERED}" == "AThis system is not yet registered" ]
        then
            check_for_dns subscription.rhsm.redhat.com
            echo "${rhsm_msg}"
            rhsm_reg_result=$(mktemp)
            echo sudo subscription-manager register "${rhsm_cmd_opts}" --force --release="'${RHEL_RELEASE}'"|sh > "${rhsm_reg_result}" 2>&1
            RESULT="$?"
            if [ "A${RESULT}" == "A${RESULT}" ]
            then
                echo "Successfully registered $(hostname) to RHSM"
                cat "${rhsm_reg_result}"
                check_rhsm_status
                set_openshift_rhsm_pool_id
            else
                echo "$(hostname) registration to RHSM was unsuccessfull"
                cat "${rhsm_reg_result}"
            fi
        else
            echo "$(hostname) is already registered"
            check_rhsm_status
            set_openshift_rhsm_pool_id
        fi
    fi
}
    
    function get_rhsm_user_and_pass () {
        if grep '""' "${vault_vars_file}"|grep -q rhsm_username
        then
        echo -n "Enter your RHSM username and press [ENTER]: "
        read rhsm_username
        sed -i "s/rhsm_username: \"\"/rhsm_username: "$rhsm_username"/g" "${vaulted_file}"
    fi
    if grep '""' "${vault_vars_file}"|grep -q rhsm_password
    then
        unset rhsm_password
        echo -n 'Enter your RHSM password and press [ENTER]: '
        read_sensitive_data
        rhsm_password="${sensitive_data}"
        sed -i "s/rhsm_password: \"\"/rhsm_password: "$rhsm_password"/g" "${vaulted_file}"
    fi
}

function get_subscription_pool_id () {
    PRODUCT=$1

    AVAILABLE=$(sudo subscription-manager list --available --matches "${PRODUCT}" | grep Pool | awk '{print $3}' | head -n 1)
    CONSUMED=$(sudo subscription-manager list --consumed --matches "${PRODUCT}" --pool-only)

    if [ "A${AVAILABLE}" != "A" ]
    then
       echo "Find pool id for ${PRODUCT} using the available search"
       POOL_ID="${AVAILABLE}"
    elif [ "A${CONSUMED}" != "A" ]
    then
       echo "Found the pool id for {PRODUCT} using the consumed search"
       POOL_ID="${CONSUMED}"
    else
        cat "${project_dir}/docs/subscription_pool_message"
        exit 1
    fi
}
