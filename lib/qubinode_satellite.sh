#!/bin/bash


## Ansible
SAMPLE_VARS_FILE="${project_dir}/samples/satellite_server.yml"
test -f "${SATELLITE_VARS_FILE}" || cp "${SAMPLE_VARS_FILE}" "${SATELLITE_VARS_FILE}"

## Playbooks and Vars
SATELLITE_VM_PLAYBOOK="${project_dir}/playbooks/deploy_satellite_vm.yml"
SATELLITE_SERVER_PLAYBOOK="${project_dir}/playbooks/satellite-server-install.yml"
SATELLITE_RHEL_PLAYBOOK="${project_dir}/playbooks/setup_rhel_for_satellite.yml"
SATELLITE_INSTALL_PLAYBOOK="${project_dir}/playbooks/install_satellite.yml"
SATELLITE_CONFIGURE_PLAYBOOK="${project_dir}/playbooks/configure_satellite.yml"
CREATE_DNS_ENTRIES_PLAYBOOK="${project_dir}/playbooks/create-idm-dns-entry.yml"
SATELLITE_ANSIBLE_VARS='-e "@playbooks/vars/satellite_server.yml" -e "@${idm_vars_file}" -e "@${vars_file}"'

## Default Installation variables
DEPLOY_SATELLITE_VM="no"
INSTALL_SATELLITE="no"
CONFIGURE_SATELLITE="no"

## VARS
PREFIX=$(awk '/^instance_prefix:/ {print $2}' ${vars_file})
SUFFIX=$(awk '/^hostname_suffix:/ {print $2}' "${SATELLITE_VARS_FILE}")
SATELLITE_SERVER_NAME="${PREFIX}-${SUFFIX}"
ANSIBLE_VERSION=$(awk '/^ansible_release:/ {print $2}' ${vars_file})
SAT_FQDN="${SATELLITE_SERVER_NAME}.${domain}"

## Check inventory for Satellite IP
if grep -q "${SATELLITE_SERVER_NAME}" "${project_dir}/inventory/hosts"
then
    INVENTORY_IP=$(grep "${SATELLITE_SERVER_NAME}" "${project_dir}/inventory/hosts" | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
else
    INVENTORY_IP=""
fi

## Check DNS for Satellite IP
DNS_IP=$(dig +short "${SAT_FQDN}")

## Delare Satellite server IP
if [ "A${DNS_IP}" != "A" ] && [ "A${INVENTORY_IP}" != "A" ]
then
    if [ "A${DNS_IP}" == "A${INVENTORY_IP}" ]
    then
        SATELLITE_SERVER_IP="${DNS_IP}"
        SATELLITE_SERVER_DNS="yes"
    fi
elif [ "A${DNS_IP}" != "A" ]
then
    SATELLITE_SERVER_IP="${DNS_IP}"
    SATELLITE_SERVER_DNS="yes"
elif [ "A${INVENTORY_IP}" != "A" ]
then
    SATELLITE_SERVER_IP="${DNS_IP}"
    SATELLITE_SERVER_DNS="yes"
else 
    SATELLITE_SERVER_IP=""
    SATELLITE_SERVER_DNS="no"
fi

## Check if Satellite DNS has been created
if [ "A${SATELLITE_SERVER_IP}" != "A" ]
then
    SATELLITE_SERVER_DNS=$(dig +short -x "${SATELLITE_SERVER_IP}")
fi

function satellite_install_msg () {
    printf "\n\n ${yel}*******************************************************************************${end}\n"
    printf " ${yel}*${end}  Red Hat Satellite Deployment Completed      ${yel}*${end}\n\n"
    printf "      Hostname: ${SAT_FQDN} \n"
    printf "      Username: $(whoami) \n"
    printf "      Password: Tun the below command to view the vault variable *admin_user_password* \n\n"
    printf "      Run: ansible-vault view ${project_dir}/playbooks/vars/vault.yml \n\n"
    printf " ${yel}*******************************************************************************${end}\n\n"
}

function satellite_configure_msg () {
    printf "\n\n ${yel}*******************************************************************************${end}\n"
    printf " ${yel}*${end}  The Satellite server has been deployed with login details below.      ${yel}*${end}\n\n"
    printf "      Web Url: https://${SAT_FQDN} \n"
    printf "      Username: $(whoami) \n"
    printf "      Password: Tun the below command to view the vault variable *admin_user_password* \n\n"
    printf "      Run: ansible-vault view ${project_dir}/playbooks/vars/vault.yml \n\n"
    printf " ${yel}*******************************************************************************${end}\n\n"
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

function update_satellite_ip () {
    IP=$(awk -v var="${SATELLITE_SERVER_NAME}" '$0 ~ var {print $0}' "${project_dir}/inventory/hosts"|grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
    if [ "A${IP}" != "A" ]
    then
        if ! grep -q "${IP}" "${SATELLITE_VARS_FILE}"
        then
            sed -i "s/sat_server_ip:.*/sat_server_ip: "$IP"/g" "${SATELLITE_VARS_FILE}"
        fi
    else
        echo "Could not find ip address for Satellite server."
        exit 1
    fi
}

function qubinode_satellite_install_options () {
    local error_msg="${red}The configuration of the Satellite server was unsuccessful.${end}"
    local success_msg="${cyn}The configuration of the Satellite server was successful.${end}"

    ## Display Satellite Installation Message
    satellite_welcome_msg 
    confirm "    ${blu}Continue with the installation of Satellite?${end} ${cyn}yes/no${end}"
    if [ "A${response}" != "Ayes" ]
    then
        exit 0
    fi

    printf "%s\n\n" ""
    printf "%s\n\n" "    Check for the Satellite manifest file"
    if [ ! -f "${project_dir}/satellite-server-manifest.zip" ]
    then
        printf "%s\n\n" "  Could not find a Satellite manifest."
        printf "%s\n" "  Please save your satellite manifest to ${project_dir}/satellite-server-manifest.zip"
        printf "%s\n" "  and run the installer again."
        exit 1
    fi

    printf "%s\n" "    Check for Red Hat Satellite Subscription Pool"
    if grep '""' "${SATELLITE_VARS_FILE}"|grep -q satellite_pool_id
    then
        echo "Checking for Red Hat Satellite Subscription Pool"
        get_subscription_pool_id 'Red Hat Satellite'
        # set subscription pool id
        if [ "A${POOL_ID}" != "A" ]
        then
            echo "Setting RHSM pool-id ${POOL_ID}"
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

    printf "%s\n\n" "    Check if Satellite is already installed"
    SAT_CON_CHECK_FILE="$(mktemp)"
    ansible-playbook "${SATELLITE_VM_PLAYBOOK}" "${SATELLITE_ANSIBLE_VARS}" -t check-satellite -vvv > "${SAT_CON_CHECK_FILE}"
    SATELLITE_INSTALLED=$(cat "${SAT_CON_CHECK_FILE}" |grep -m1 'satellite_is_installed:' |awk '/satellite_is_installed:/ {print $2}')
    
    printf "%s\n\n" "    Set the qcow image to $qcow_image_name"
    sed -i "s/cloud_init_vm_image:.*/cloud_init_vm_image: "$qcow_image_name"/g" "${SATELLITE_VARS_FILE}"

    if [ "A${SATELLITE_INSTALLED}" != "Afalse" ]
    then
        printf "%s\n\n" "    Satellite server is already deployed and running"
        printf "%s\n" "    Choose ${cyn}yes${end} below to run or re-run the Satellite configuration"
        printf "%s\n" "    Choose ${cyn}no${end} to exit"
        confirm "    ${blu}Do you want to configure or re-run the configuration?${end} ${cyn}yes/no${end}"
        if [ "A${response}" == "Ayes" ]
        then
            CONFIGURE_SATELLITE="yes"
        else
            exit 0
        fi
    elif [ "A${SATELLITE_SERVER_IP}" != "A" ]
    then
        if ! ssh -o StrictHostKeyChecking=no "${ADMIN_USER}@${SATELLITE_SERVER_IP}" 'exit'
        then
            ## Satellite VM IP found but cannot ssh to the VM
            DEPLOY_SATELLITE_VM="yes"
            INSTALL_SATELLITE="yes"
            CONFIGURE_SATELLITE="yes"
        else
            ## Satellite VM IP found and ssh was successful
            INSTALL_SATELLITE="yes"
            CONFIGURE_SATELLITE="yes"
        fi
    else
        ## Performing default install
        DEPLOY_SATELLITE_VM="yes"
        INSTALL_SATELLITE="yes"
        CONFIGURE_SATELLITE="yes"
    fi
}

function qubinode_deploy_satellite  () {
    
    ## Determine the Satellite server installation options
    qubinode_satellite_install_options

            echo "DEPLOY_SATELLITE_VM=$DEPLOY_SATELLITE_VM"
            echo "INSTALL_SATELLITE=$INSTALL_SATELLITE"
            echo "CONFIGURE_SATELLITE=$CONFIGURE_SATELLITE"
            echo "SATELLITE_SERVER_DNS=$SATELLITE_SERVER_DNS"
            echo "SATELLITE_SERVER_IP=$SATELLITE_SERVER_IP"
            echo "SATELLITE_SERVER_NAME=$SATELLITE_SERVER_NAME"

            echo "DNS_IP=$DNS_IP"
echo "INVENTORY_IP=$INVENTORY_IP"
echo "SATELLITE_SERVER_IP=$SATELLITE_SERVER_IP"
echo "SATELLITE_SERVER_DNS=$SATELLITE_SERVER_DNS"



    
    if [ "A${DEPLOY_SATELLITE_VM}" == "Ayes" ]
    then
        printf "%s\n\n" "    Ensure host is setup correctly"
        qubinode_setup

        printf "%s\n\n" "    Deploy Satellite RHEL VM"
        ansible-playbook "${SATELLITE_VM_PLAYBOOK}" || exit $?

        printf "%s\n\n" "    Create Satellite required DNS entries"
        ansible-playbook "${CREATE_DNS_ENTRIES_PLAYBOOK}" "${SATELLITE_ANSIBLE_VARS}" || exit $?
        update_satellite_ip

    fi

    ## Install Satellite server
    if [ "A${INSTALL_SATELLITE}" == "Ayes" ]
    then
        if [ "A${SATELLITE_SERVER_DNS}" == "A" ]
        then
            update_satellite_ip
            printf "%s\n\n" "    Create Satellite required DNS entries"
            ansible-playbook "${CREATE_DNS_ENTRIES_PLAYBOOK}" "${SATELLITE_ANSIBLE_VARS}" || exit $?
        fi

        printf "%s\n\n" "    Configure RHEL Satellite VM"
        ansible-playbook "${SATELLITE_RHEL_PLAYBOOK}" || exit $?

        printf "%s\n\n" "    Deploy the Satellite Server"
        ansible-playbook "${SATELLITE_INSTALL_PLAYBOOK}" || exit $?
    fi


    ## Configure Satellite
    if [ "A${CONFIGURE_SATELLITE}" == "Ayes" ]
    then
        printf "%s\n\n" "    Configure Satellite server"
        ansible-playbook "${SATELLITE_CONFIGURE_PLAYBOOK}" || exit $?
    fi

#    if [ "A${SATELLITE_SERVER_DNS}" == "A" ]
#    then
#
#    elif [ "A${DEPLOY_SATELLITE_VM}" == "Ayes" ]
#    then
#        printf "%s\n\n" "    Ensure host is setup correctly"
#        qubinode_setup
#
#        printf "%s\n\n" "    Deploy Satellite RHEL VM"
#        ansible-playbook "${SATELLITE_VM_PLAYBOOK}" || exit $?
#
#        printf "%s\n\n" "    Create Satellite required DNS entries"
#        ansible-playbook "${CREATE_DNS_ENTRIES_PLAYBOOK}" "${SATELLITE_ANSIBLE_VARS}" || exit $?
#    else
#       if ! ssh -o StrictHostKeyChecking=no "${ADMIN_USER}@${SATELLITE_SERVER_DNS}"
#       then
#          printf "%s\n\n" "    Deploy Satellite RHEL VM"
#          ansible-playbook "${SATELLITE_VM_PLAYBOOK}" || exit $?
#
#          printf "%s\n\n" "    Create Satellite required DNS entries"
#          update_satellite_ip
#          ansible-playbook "${CREATE_DNS_ENTRIES_PLAYBOOK}" "${SATELLITE_ANSIBLE_VARS}" || exit $?  
#       fi  
#    fi
#



#    ## Install the Satellite server
#    if [ "A${INSTALL_SATELLITE}" == "Ayes" ]
#    then
#        printf "%s\n\n" "    Deploy the Satellite Server"
#        
#        ## Ensure required collections are present (probable going to need to run this on the satellite server)
#        #cd ${project_dir}
#        #ansible-galaxy collection install -r collections/requirements.yml
#
#
#        ansible-playbook "${SATELLITE_INSTALL_PLAYBOOK}" || exit $?
#    fi
#

#
#    ## Ensure Inventory as the correct Satellite IP
    update_satellite_ip

    ## Display Satellite Install Message
    satellite_install_msg

}

function qubinode_teardown_satellite () {
    confirm "    ${blu}This action will delete the Satellite servr, continue?${end} ${cyn}yes/no${end}"
    if [ "A${response}" == "Ano" ]
    then
        exit 0
    fi

   # Deploy or teardown Satellite
   if [ "A${teardown}" == "Atrue" ]
   then
       if [ "A${SATELLITE_SERVER_DNS}" != "A" ]
       then
          echo "Removing Satelite DNS records"
          #ansible-playbook "${SATELLITE_VM_PLAYBOOK}" --extra-vars "vm_teardown=true" -t create_dns_records || exit $?
          ansible-playbook playbooks/create-idm-dns-entry.yml "${SATELLITE_ANSIBLE_VARS}" -e "vm_teardown=true" || exit $?
       fi

       if sudo virsh list | grep -q "${SATELLITE_SERVER_NAME}"
       then
           echo "Removing Satellite VM"
           ansible-playbook "${SATELLITE_VM_PLAYBOOK}" --extra-vars "vm_teardown=true" --skip-tags create_dns_records || exit $?
       else
           printf " ${red}Red Hat Satellite server ${grn}${SAT_FQDN}${end} ${red}not running${end}\n\n"
       fi
    fi
}


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