#!/bin/bash
kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
vars_file="${project_dir}/playbooks/vars/all.yml"
RHEL_VERSION=$(awk '/rhel_version:/ {print $2}' "${vars_file}")
RUN_KNI_ON_RHPDS=$(awk '/run_kni_lab_on_rhpds/ {print $2}' "${vars_file}")

# This function checks the status of RHSM registration
function check_rhsm_status () {
    if grep Fedora /etc/redhat-release || [[ $(get_distro) == "centos" ]]|| [[ $(get_distro) == "rocky"  ]] || [[ $RUN_KNI_ON_RHPDS == "yes"  ]] ; 
    then
        echo "Skipping checking RHSM status"
    else 
        sudo subscription-manager identity > /dev/null 2>&1
        RESULT="$?"
        if [ "A${RESULT}" == "A1" ]
        then
            printf "%s\n" " ${red}This system is not yet registered to Red Hat.${end}"
            printf "%s\n\n" " Please run: ${grn}qubinode-installer -m rhsm${end}"
            exit 1
        fi

        status_result=$(mktemp)
        sudo subscription-manager status > "${status_result}" 2>&1
        status=$(awk -F: '/Overall Status:/ {print $2}' "${status_result}"|sed 's/^ *//g')
        if [ "A${status}" != "ACurrent" ]
        then
            sudo subscription-manager refresh > /dev/null 2>&1
            sudo subscription-manager attach --auto > /dev/null 2>&1
        fi

        #check again
        sudo subscription-manager status > "${status_result}" 2>&1
        status=$(awk -F: '/Overall Status:/ {print $2}' "${status_result}"|sed 's/^ *//g')
        if [ "A${status}" != "ACurrent" ]
        then
            printf "%s\n" " Cannot determine the subscription status of ${yel}$(hostname)${end}"
            printf "%s\n" " Error details are: "
            cat "${status_result}"
            printf "%s\n\n" " Please resolved and try again"
            exit 1
        fi
    fi
}

function configure_ansible_aap_creds(){
    printf "%s\n" "  ${yel}****************************************************************************${end}"
    printf "%s\n\n" "    ${cyn}        Enter Credentials for Application Deployments${end}"
    decrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
    if grep '""' "${vault_vars_file}"|grep -q rhsm_username
    then
        decrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
        get_rhsm_user_and_pass
        encrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
    fi 

    if grep '""' "${vault_vars_file}"|grep -q rhsm_activationkey
    then
        echo -n "   ${blu}Enter your RHSM activation key and press${end} ${grn}[ENTER]${end}: "
        echo -n "   ${blu}See Creating Red Hat Customer Portal Activation Keys${end} ${grn}https://access.redhat.com/articles/1378093${end}: "
        read rhsm_activationkey
        unset rhsm_org
        sed -i "s/rhsm_activationkey: \"\"/rhsm_activationkey: "$rhsm_activationkey"/g" "${vault_vars_file}"
    fi
    if grep '""' "${vault_vars_file}"|grep -q rhsm_org
    then
        echo -n "   ${blu}Enter your RHSM ORG ID and press${end} ${grn}[ENTER]${grn}: "
        read_sensitive_data
        rhsm_org="${sensitive_data}"
        sed -i "s/rhsm_org: \"\"/rhsm_org: "$rhsm_org"/g" "${vault_vars_file}"
    fi

    # encrypt ansible vault
    encrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1

    if [ ! -f $HOME/offline_token ];
    then
        read -p "   Offline token not found you can find it at https://access.redhat.com/management/api: ${end}" OFFLINE_TOKEN
        echo $OFFLINE_TOKEN > $HOME/offline_token
    fi

}

function ask_user_for_rhsm_credentials () {
    # decrypt ansible vault file
    decrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
    if grep Fedora /etc/redhat-release ||  [[ $(get_distro) == "centos" ]] || [[ $(get_distro) == "rocky" ]] || [[ $RUN_KNI_ON_RHPDS == "yes"  ]] ; 
    then
        echo "Skipping checking RHSM status"
    elif grep '""' "${vars_file}"|grep -q rhsm_reg_method
    then
        printf "%s\n" "  ${yel}****************************************************************************${end}"
        printf "%s\n\n" "    ${cyn}        Red Hat Subscription Registration${end}"

        printf "%s\n\n" "   ${yel}Your credentials for access.redhat.com is needed.${end}"
        printf "%s\n"  "   This is use to register this instance of RHEL and"
        printf "%s\n"  "   along with the other RHEL vms that will be deployed."
        printf "%s\n\n"  ""
        printf "%s\n"  "   There are two types of credentials:"
        printf "%s\n"  "     (*) ${yel}activation key${end}"
        printf "%s\n\n"  "     (*) ${yel}username/password${end}"
        printf "%s\n"  "   The username/password is what's more commonly use."
        printf "%s\n\n"  "   The activation key is commonly use with a Satellite server."

        printf "%s\n" "   ${blu}Which option are you using to register the system?${end}"
        rhsm_msg=("Activation Key" "Username and Password")
        createmenu "${rhsm_msg[@]}"
        rhsm_reg_method=($(echo "${selected_option}"))
        sed -i "s/rhsm_reg_method: \"\"/rhsm_reg_method: "$rhsm_reg_method"/g" "${vars_file}"
        if [ "A${rhsm_reg_method}" == "AUsername" ];
        then
            decrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
            get_rhsm_user_and_pass
            encrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
        elif [ "A${rhsm_reg_method}" == "AActivation" ];
        then
            if grep '""' "${vault_vars_file}"|grep -q rhsm_activationkey
            then
                echo -n "   ${blu}Enter your RHSM activation key and press${end} ${grn}[ENTER]${end}: "
                read rhsm_activationkey
                unset rhsm_org
                sed -i "s/rhsm_activationkey: \"\"/rhsm_activationkey: "$rhsm_activationkey"/g" "${vault_vars_file}"
            fi
            if grep '""' "${vault_vars_file}"|grep -q rhsm_org
            then
                echo -n "   ${blu}Enter your RHSM ORG ID and press${end} ${grn}[ENTER]${grn}: "
                read_sensitive_data
                rhsm_org="${sensitive_data}"
                sed -i "s/rhsm_org: \"\"/rhsm_org: "$rhsm_org"/g" "${vault_vars_file}"
            fi
        fi
    elif grep '""' "${vault_vars_file}"|grep -q rhsm_username
    then
        rhsm_reg_method=$(awk '/rhsm_reg_method/ {print $2}' "${vars_file}")
        decrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
        if [ "A${rhsm_reg_method}" != "AActivation" ]
        then
            get_rhsm_user_and_pass
        fi
        encrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
    else
        printf "%s\n\n" "   Credentials for RHSM is already collected."
    fi

    # encrypt ansible vault
    encrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
}


# this function checks if the system is registered to RHSM
# validate the registration or register the system
# if it's not registered
function qubinode_rhsm_register () {
    if grep Fedora /etc/redhat-release ||  [[ $(get_distro) == "centos" ]]|| [[ $(get_distro) == "rocky"  ]] || [[ $RUN_KNI_ON_RHPDS == "yes"  ]] ; 
    then
        printf "%s\n" " Skipping registering to RHSM"
        COLLECT_AAP_CREDS=$(awk '/ansible_automation_platform:/ {print $2}' "${vars_file}")
        COLLECT_CEPH_CREDS=$(awk '/enable_ceph_deployment:/ {print $2}' "${vars_file}")
        if [ "A${COLLECT_AAP_CREDS}" == "Atrue" ] || [ "A${COLLECT_CEPH_CREDS}" == "Atrue" ]
        then
            configure_ansible_aap_creds
        fi

    else
        ask_user_for_rhsm_credentials
        COLLECT_AAP_CREDS=$(awk '/ansible_automation_platform:/ {print $2}' "${vars_file}")
        COLLECT_CEPH_CREDS=$(awk '/enable_ceph_deployment:/ {print $2}' "${vars_file}")
        if [ "A${COLLECT_AAP_CREDS}" == "Atrue" ] || [ "A${COLLECT_CEPH_CREDS}" == "Atrue" ]
        then
            configure_ansible_aap_creds
        fi
        qubinode_required_prereqs
        vault_vars_file="${vault_vars_file}"
        varsfile="${vars_file}"
        does_exist=$(does_file_exist "${vault_vars_file} ${vars_file}")
        if [ "A${does_exist}" == "Ano" ]
        then
            printf "%s\n" " The file ${yel}${vars_file}${end} and ${yel}${vault_vars_file}${end} does not exist."
            printf "%s\n" "Try running: ${grn}qubinode-installer -m setup${grn}"
            exit 1
        fi
   
        # load kvmhost variables
        kvm_host_variables
 
        IS_REGISTERED_tmp=$(mktemp)
        sudo subscription-manager identity > "${IS_REGISTERED_tmp}" 2>&1
    
        # decrypt ansible vault
        decrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
    
        # Gather subscription infomration
        rhsm_reg_method=$(awk '/rhsm_reg_method/ {print $2}' "${vars_file}")
        if [ "A${rhsm_reg_method}" == "AUsername" ]
        then
            rhsm_msg=" Registering system to rhsm using your username/password."
            rhsm_username=$(awk '/rhsm_username/ {print $2}' "${vault_vars_file}")
            rhsm_password=$(awk '/rhsm_password/ {print $2}' "${vault_vars_file}")
            rhsm_cmd_opts="--username='${rhsm_username}' --password='${rhsm_password}'"
        elif [ "A${rhsm_reg_method}" == "AActivation" ]
        then
            rhsm_msg=" Registering system to rhsm using your activaiton key."
            rhsm_org=$(awk '/rhsm_org/ {print $2}' "${vault_vars_file}")
            rhsm_activationkey=$(awk '/rhsm_activationkey/ {print $2}' "${vault_vars_file}")
            rhsm_cmd_opts="--org='${rhsm_org}' --activationkey='${rhsm_activationkey}'"
        else
            printf "%s\n" " The value of ${blue}rhsm_reg_method${end} in "${vars_file}" is not a valid value."
            printf "%s\n" " Valid options are ${yel}Activation${end} or ${yel}Username${end}"
            printf "%s\n" " Try running: ${grn}qubinode-installer -m setup${end}"
            exit 1
        fi
    
        encrypt_ansible_vault "${vault_vars_file}" > /dev/null 2>&1
    
        IS_REGISTERED=$(grep -o 'This system is not yet registered' "${IS_REGISTERED_tmp}")
        if [ "A${IS_REGISTERED}" == "AThis system is not yet registered" ]
        then
            check_for_dns subscription.rhsm.redhat.com
            printf "%s\n" ""
            printf "%s\n" " ${rhsm_msg}"
            rhsm_reg_result=$(mktemp)
            local rhsm_rhel_major=$(sed -rn 's/.*([0-9])\.[0-9].*/\1/p' /etc/redhat-release)
            if [ "A${rhsm_rhel_major}" == "A8" ]
            then
               RHEL_RELEASE=$(awk '/rhel8_version:/ {print $2}' "${vars_file}")
            elif [ "A${rhsm_rhel_major}" == "A7" ]
            then
               RHEL_RELEASE=$(awk '/rhel7_version:/ {print $2}' "${vars_file}")
            else
                RHEL_RELEASE=$(cat /etc/redhat-release | grep -o [7-8].[0-9])
            fi

            echo sudo subscription-manager register "${rhsm_cmd_opts}" --force --release="'${RHEL_RELEASE}'"|sh > "${rhsm_reg_result}" 2>&1
            RESULT="$?"
            if [ ${RESULT} -eq 0 ]
            then
                printf "%s\n\n" "  ${yel}Successfully registered $(hostname) to RHSM${end}"
            else
                printf "%s\n" " ${red}$(hostname) registration to RHSM was unsuccessfull.${end}"
                cat "${rhsm_reg_result}"
            fi
        else
            # this variables isn't being used at the moment
            system_already_registered=yes
            #printf "%s\n" " ${yel}$(hostname)${end} ${blu}is already registered${end}"
        fi
    fi

    # Check for RHSM values
    if [[ -f ${vault_vars_file} ]] && [[ -f /usr/bin/ansible-vault ]]
    then
        rhsm_password='""'
        rhsm_username='""'
        if ansible-vault view "${vault_vars_file}" >/dev/null 2>&1
        then
            rhsm_password=$(ansible-vault view ${vault_vars_file}|awk '/rhsm_password:/ {print $2;exit}')
            rhsm_username=$(ansible-vault view ${vault_vars_file}|awk '/rhsm_username:/ {print $2;exit}')
        else
            rhsm_password=$(awk '/rhsm_password:/ {print $2;exit}' ${vault_vars_file})
            rhsm_username=$(awk '/rhsm_username:/ {print $2;exit}' ${vault_vars_file})
        fi

    fi

    # RHSM setup completed
    RHSM_COMPLETED=$(awk '/qubinode_installer_rhsm_completed:/ {print $2}' "${vars_file}")
    #if [ "A${RHSM_COMPLETED}" == "Ayes" ]
    if [ "A${IS_REGISTERED}" != "AThis system is not yet registered" ]
    then
        sed -i "s/qubinode_installer_rhsm_completed:.*/qubinode_installer_rhsm_completed: yes/g" "${vars_file}"
        printf "%s\n" " ${yel}RHSM setup completed${end}"
    fi 
    # Push changes to repo
    enable_gitops=$(awk '/enable_gitops:/ {print $2;exit}' "${vars_file}")
    if [ "A${enable_gitops}" == "Atrue" ]
    then
        push_to_repo all.yml
    fi

}
    
function get_rhsm_user_and_pass () {
    if grep '""' "${vault_vars_file}"|grep -q rhsm_username
    then
        printf "%s\n\n" ""
        echo -n "   ${blu}Enter your RHSM username and press${end} ${grn}[ENTER]${end}: "
        read rhsm_username
        sed -i "s/rhsm_username: \"\"/rhsm_username: "$rhsm_username"/g" "${vault_vars_file}"
    fi

    if grep '""' "${vault_vars_file}"|grep -q rhsm_password
    then
        unset rhsm_password
        echo -n "   ${blu}Enter your RHSM password and press${end} ${grn}[ENTER]${end}: "
        read_sensitive_data
        rhsm_password="${sensitive_data}"
        sed -i "s/rhsm_password: \"\"/rhsm_password: "$rhsm_password"/g" "${vault_vars_file}"
        printf "%s\n" ""
    fi
}

function get_subscription_pool_id () {
    PRODUCT=$1
    AVAILABLE=$(sudo subscription-manager list --available --matches "${PRODUCT}" | grep Pool | awk '{print $3}' | head -n 1)
    CONSUMED=$(sudo subscription-manager list --consumed --matches "${PRODUCT}" --pool-only)

    if [ "A${AVAILABLE}" != "A" ]
    then
       #printf "%s\n" " Found the pool id for ${PRODUCT} using the available search."
       POOL_ID="${AVAILABLE}"
    elif [ "A${CONSUMED}" != "A" ]
    then
       #printf "%s\n" "Found the pool id for {PRODUCT} using the consumed search."
       POOL_ID="${CONSUMED}"
    else
        cat "${project_dir}/docs/subscription_pool_message"
        exit 1
    fi
}

