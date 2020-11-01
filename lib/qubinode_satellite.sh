#!/bin/bash


# VARIBLES
SAMPLE_VARS_FILE="${project_dir}/samples/satellite_server.yml"
test -f "${SATELLITE_VARS_FILE}" || cp "${SAMPLE_VARS_FILE}" "${SATELLITE_VARS_FILE}"
PREFIX=$(awk '/^instance_prefix:/ {print $2}' $project_dir/playbooks/vars/all.yml)
SUFFIX=$(awk '/^hostname_suffix:/ {print $2}' "${SATELLITE_VARS_FILE}")
SATELLITE_SERVER_NAME="${PREFIX}-${SUFFIX}"
SATELLITE_SERVER_IP=$(awk -v var="${SATELLITE_SERVER_NAME}" '$0 ~ var {print $2}' "${project_dir}/inventory/hosts" |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
ANSIBLE_VERSION=$(awk '/^ansible_release:/ {print $2}' $project_dir/playbooks/vars/all.yml)

# Playbooks
SATELLITE_VM_PLAYBOOK="${project_dir}/playbooks/deploy_satellite_vm.yml"
SATELLITE_SERVER_PLAYBOOK="${project_dir}/playbooks/satellite-server-install.yml"


function satellite_server_maintenance () {
   STATUS=$(sudo virsh list --all|awk -v var="${SATELLITE_SERVER_NAME}" '$0 ~ var {print $3}')
   if [ "${product_maintenance}" == "shutdown" ]
   then
       if [ "A${STATUS}" == "Arunning" ]
       then
           echo "Shutting down Satellite VM: ${SATELLITE_SERVER_NAME}"
           ansible "${SATELLITE_SERVER_NAME}" -m shell -a "shutdown -h now" -i "${project_dir}/inventory/hosts" -b 
       fi
   elif [ "${product_maintenance}" == "start" ]
   then
       if [ "A${STATUS}" != "Arunning" ]
       then
           echo "Starting Up Satellite VM: ${SATELLITE_SERVER_NAME}"
           sudo virsh start "${SATELLITE_SERVER_NAME}"
       fi
   fi
   exit 0
}

function update_satellite_ip () {
    IP=$(awk -v var="${SATELLITE_SERVER_NAME}" '$0 ~ var {print $0}' "${project_dir}/inventory/hosts"|grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
    if [ "A${IP}" != "A" ]
    then
        if ! grep 'sat_server_ip:' "${SATELLITE_VARS_FILE}" |grep -q $IP
        then
            sed -i "s/sat_server_ip:.*/sat_server_ip: "$IP"/g" "${SATELLITE_VARS_FILE}"
        fi
    else
        echo "Could not find ip address for Satellite server."
        exit 1
    fi
}

function satellite_install_msg () {
    printf "\n\n ${yel}*******************************************************************************${end}\n"
    printf " ${yel}*${end}  Red Hat Satellite Deployment Completed      ${yel}*${end}\n\n"
    printf "      Hostname: ${SATELLITE_SERVER_NAME}.${domain} \n"
    printf "      Username: $(whoami) \n"
    printf "      Password: the vault variable *admin_user_password* \n\n"
    printf "      Run: ansible-vault edit ${project_dir}/playbooks/vars/vault.yml \n\n"
    printf " ${yel}*******************************************************************************${end}\n\n"
}

function satellite_configure_msg () {
    printf "\n\n ${yel}*******************************************************************************${end}\n"
    printf " ${yel}*${end}  The Satellite server has been deployed with login details below.      ${yel}*${end}\n\n"
    printf "      Web Url: https://${SATELLITE_SERVER_NAME}.${domain} \n"
    printf "      Username: $(whoami) \n"
    printf "      Password: the vault variable *admin_user_password* \n\n"
    printf "      Run: ansible-vault edit ${project_dir}/playbooks/vars/vault.yml \n\n"
    printf " ${yel}*******************************************************************************${end}\n\n"
}

function qubinode_configure_satellite () {
    local error_msg="${red}The configuration of the Satellite server was unsuccessful.${end}"
    local success_msg="${cyn}The configuration of the Satellite server was successful.${end}"

    ansible-galaxy collection install -r playbooks/requirements.yml
    pip install --user apypie
    pip install --user ipaddress
    pip install --user PyYAML

    # configure satellite
    if ansible-playbook ${project_dir}/playbooks/satellite_server_setup.yml
    #ansible-playbook ${project_dir}/playbooks/satellite_server_setup.yml -e "install_apypie=yes"
    then
        SATELLITE_SETUP=success
        satellite_server_setup_msg="${success_msg}"
        satellite_configure_msg
    else
        SATELLITE_SETUP=failed
        satellite_server_setup_msg="${error_msg}"
    fi
}

function satellite_welcome_msg () {
    printf "\n\n ${yel}    *************************************************************${end}\n"
    printf "     ${yel}**${end}   Red Hat Satellite 6 Instalaltion and Configuration    ${yel}**${end}\n\n"
    printf "     This will install the latest Satellite 6 server and configure\n"
    printf "     products, sync repos, setup content views and activation keys.\n"
    printf "     You will need to ensure you a copy of your manifest stored in \n"
    printf "     the Qubinode project folder as ${blu}satellite-server-manifest.zip${end}.\n"
    printf "     ${yel}*************************************************************${end}\n\n"
}

function qubinode_install_satellite () {
    satellite_welcome_msg
    confirm "    ${blu}Continue with the installation of Satellite?${end} ${cyn}yes/no${end}"
    if [ "A${response}" == "Ayes" ]
    then
        # Ensure the host system is setup
        if [ ! -f "${project_dir}/satellite-server-manifest.zip" ]
        then
            printf "%s\n\n" "  Could not find a Satellite manifest."
            printf "%s\n" "  Please save your satellite manifest to ${project_dir}/satellite-server-manifest.zip"
            printf "%s\n" "  and run the installer again."
            exit
        fi

        #Check if Satellite DNS has been created
        if [ "A${SATELLITE_SERVER_IP}" != "A" ]
        then
            SATELLITE_SERVER_DNS=$(dig +short -x "${SATELLITE_SERVER_IP}")
        fi

        # Ensure host is setup as a qubinode
        qubinode_setup

        # Ensure IdM is deployed
        isIdMrunning
        if [ "A${idm_running}" == "Afalse" ]
        then
            qubinode_deploy_idm
        fi

        # Start of Satellite deployment
        if grep '""' "${SATELLITE_VARS_FILE}"|grep -q satellite_pool_id
        then
            echo "Checking for Red Hat Satellite Subscription Pool"
            get_subscription_pool_id 'Red Hat Satellite'
            # set subscription pool id
            if [ "A${POOL_ID}" != "A" ]
            then
                echo "Setting RHSM pool-id"
                if grep '""' "${SATELLITE_VARS_FILE}"|grep -q satellite_pool_id
                then
                    echo "Found Satellite Pool ID $satellite_pool_id."
                    sed -i "s/satellite_pool_id: \"\"/satellite_pool_id: $POOL_ID/g" "${SATELLITE_VARS_FILE}"
                fi
            else
                echo "Could locate a Red Hat Satellite Subscription Pool"
                echo "You can manually add it to ${SATELLITE_VARS_FILE} and run the script again"
                exit 1
            fi
        fi

        # set the qcow image to be used
        sed -i "s/cloud_init_vm_image:.*/cloud_init_vm_image: "$qcow_image_name"/g" "${SATELLITE_VARS_FILE}"

        # Ensure required role exist
        check_for_required_role swygue-install-satellite
        if [ "A${SATELLITE_SERVER_IP}" != "A" ]
        then
            # Satellite server ip found in inventory host
            #Checking if Satellite deployment is needed
            if ! ssh -o StrictHostKeyChecking=no "${ADMIN_USER}@${SATELLITE_SERVER_IP}" 'exit'
            then
                echo "Deploy Satellite VM and create DNS records"
                ansible-playbook "${SATELLITE_VM_PLAYBOOK}" || exit $?
                update_satellite_ip
                ansible-playbook "${SATELLITE_SERVER_PLAYBOOK}" || exit $?
                #qubinode_configure_satellite
                satellite_install_msg
            elif [ "A${SATELLITE_SERVER_DNS}" == "A" ]
            then
            # Deploy the satellite server VM if the ip address
            # wasn't already in inventory/hosts
                echo "Create Satellite server DNS records"
                ansible-playbook "${SATELLITE_VM_PLAYBOOK}" -t create_dns_records || exit $?
                update_satellite_ip
                ansible-playbook "${SATELLITE_SERVER_PLAYBOOK}" || exit $?
                qubinode_configure_satellite
                satellite_install_msg
            else
                # need to add a check to verify login to the satellite server then
                # and if not run other steps
                #echo "Update DNS and Satellite server IP"
                ansible-playbook "${SATELLITE_VM_PLAYBOOK}" -t create_dns_records || exit $?
                update_satellite_ip
                ansible-playbook "${SATELLITE_SERVER_PLAYBOOK}" || exit $?
                qubinode_configure_satellite
                satellite_install_msg
            fi
        else
            echo "Deploy Satellite VM and create DNS records"
            ansible-playbook "${SATELLITE_VM_PLAYBOOK}" || exit $?
            update_satellite_ip
            ansible-playbook "${SATELLITE_SERVER_PLAYBOOK}" || exit $?
            qubinode_configure_satellite
            satellite_install_msg
        fi
    else
        exit
    fi
}

function qubinode_deploy_satellite () {
    SATELLITE_STATUS=$(ansible-playbook "${project_dir}/playbooks/satellite-server-install.yml" -t check-satellite | grep 'status:')
    RESULT=$(echo $SATELLITE_STATUS | awk -F: '{print $2}'|tr -d '[:space:]')

    if [ "A${product_maintenance}" != "A" ]
    then
       satellite_server_maintenance
    elif [ "A${teardown}" == "Atrue" ]
    then
        echo "Tear Down Satellite"
        qubinode_teardown_satellite
    else
        if [[ "${RESULT}" == "-1" ]] || [[ "${RESULT}" == "" ]]
        then
            qubinode_install_satellite
        else
            echo "Satellite server appears to be already deployed"
            echo "https://{{ satellite_hostname }}.{{ satellite_domain }}"
        fi
    fi
}



function qubinode_teardown_satellite () {
   # Deploy or teardown Satellite
   if [ "A${teardown}" == "Atrue" ]
   then
       if [ "A${SATELLITE_SERVER_DNS}" != "A" ]
       then
          echo "Removing Satelite DNS records"
          ansible-playbook "${SATELLITE_VM_PLAYBOOK}" --extra-vars "vm_teardown=true" -t create_dns_records || exit $?
       fi

       if sudo virsh list | grep -q "${SATELLITE_SERVER_NAME}"
       then
           echo "Removing Satellite VM"
           ansible-playbook "${SATELLITE_VM_PLAYBOOK}" --extra-vars "vm_teardown=true" --skip-tags create_dns_records || exit $?
       fi
    fi
}
