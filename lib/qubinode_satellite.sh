#!/bin/bash

SATELLITE_SERVER_NAME="qbn-sat01"
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

function qubinode_setup_satellite () {
    ANSIBLE_VERSION="2.8"
    CURRENT_ANSIBLE_VERSION=$(ansible --version | awk '/^ansible/ {print $2}')
    ANSIBLE_VERSION_GOOD=$(awk -vv1="$ANSIBLE_VERSION" -vv2="$CURRENT_ANSIBLE_VERSION" 'BEGIN { print (v2 >= v1) ? "YES" : "NO" }')
    local error_msg="${red}The configuration of the Satellite server was unsuccessful.${end}"
    local success_msg="${cyn}The configuration of the Satellite server was successful.${end}"

    if [ "A${ANSIBLE_VERSION_GOOD}" == "AYES" ]
    then
        if ansible-playbook ${project_dir}/playbooks/satellite_server_setup.yml
        then
            SATELLITE_SETUP=success
            satellite_server_setup_msg="${success_msg}"
        else
            SATELLITE_SETUP=failed
            satellite_server_setup_msg="${error_msg}"
        fi
    else
        SATELLITE_SETUP=failed
        satellite_server_setup_msg="${error_msg}"
        printf "%s\n" " The version of Ansible needs to be at least $ANSIBLE_VERSION for setting up Satellite."
        printf "%s\n" " Your current Ansible version is $CURRENT_ANSIBLE_VERSION."

        if ! rpm -qa | grep -q rh-python36-python-pip
        then
            sudo subscription-manager repos --enable rhel-7-server-optional-rpms --enable rhel-server-rhscl-7-rpms
            sudo yum -y install rh-python36 rh-python36-python-pip
        fi

        if [ ! -f ${project_dir}/../.ansible/collections/ansible_collections/theforeman/foreman/MANIFEST.json ]
        then
            test -d "${project_dir}/python-env" || mkdir "${project_dir}/python-env"
            cd "${project_dir}/python-env"
            source /opt/rh/rh-python36/enable
            python3 -m venv ansible2.9.5
            source ./ansible2.9.5/bin/activate
            pip install --upgrade pip setuptools
            pip install ansible==2.9.5
            pip install apypie
            pip install ipaddress
            pip install PyYAML
            ansible-galaxy collection install theforeman.foreman
            deactivate
        fi

        cd "${project_dir}"
        source "${project_dir}/python-env/ansible2.9.5/bin/activate"
        if ansible-playbook ${project_dir}/playbooks/satellite_server_setup.yml -e "install_apypie=yes"
        then
            satellite_configure_msg
        else
            printf "%s\n" "The configuration of Satellite was not completely successful."
        fi
        deactivate
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
            #rintf "%s\n" " You can also specefiy a alternate manifest byt edit playbooks/vars/satellite_server.yml"
            exit
        fi
        qubinode_setup
        ask_user_input
        qubinode_vm_deployment_precheck

        # Ensure IdM is deployed
        qubinode_deploy_idm

        # Start of Satellite deployment
        ACTIVE_VARS_FILE="${project_dir}/playbooks/vars/satellite_server.ymll"
        SAMPLE_VARS_FILE="${project_dir}/samples/satellite_server.yml"
        test -f "${ACTIVE_VARS_FILE}" || cp "${SAMPLE_VARS_FILE}" "${ACTIVE_VARS_FILE}"
        SATELLITE_VM_PLAYBOOK="${project_dir}/playbooks/deploy_satellite_vm.yml"
        SATELLITE_SERVER_IP=$(awk '/qbn-sat/ {print $2}' "${project_dir}/inventory/hosts" |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
        SATELLITE_SERVER_PLAYBOOK="${project_dir}/playbooks/satellite-server-install.yml"

        # Check if Satellite DNS has been created
        if [ "A${SATELLITE_SERVER_IP}" != "A" ]
        then
            SATELLITE_SERVER_DNS=$(dig +short -x "${SATELLITE_SERVER_IP}")
        fi
   
     
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
                echo "The OpenShift Pool ID is not available to playbooks/vars/all.yml"
            fi
        fi

        # Ensure required role exist
        check_for_required_role swygue-install-satellite
        if [ "A${SATELLITE_SERVER_IP}" != "A" ]
        then
            echo "Checking if Satellite deployment is needed"
            if ! ssh -o StrictHostKeyChecking=no "${ADMIN_USER}@${SATELLITE_SERVER_IP}" 'exit'
            then
                echo "Deploy Satellite VM and create DNS records"
                ansible-playbook "${SATELLITE_VM_PLAYBOOK}" || exit $?
                update_satellite_ip
                ansible-playbook "${SATELLITE_SERVER_PLAYBOOK}" || exit $?
                satellite_install_msg
            elif [ "A${SATELLITE_SERVER_DNS}" == "A" ]
            then
                echo "Create Satellite server DNS records"
                ansible-playbook "${SATELLITE_VM_PLAYBOOK}" -t create_dns_records || exit $?
                update_satellite_ip
                ansible-playbook "${SATELLITE_SERVER_PLAYBOOK}" || exit $?
                satellite_install_msg
            else
                # need to add a check to verify login to the satellite server then
                # and if not run other steps
                echo "Update DNS and Satellite server IP"
                ansible-playbook "${SATELLITE_VM_PLAYBOOK}" -t create_dns_records || exit $?
                update_satellite_ip
                ansible-playbook "${SATELLITE_SERVER_PLAYBOOK}" || exit $?
                satellite_install_msg
            fi
        else
            echo "Deploy Satellite VM and create DNS records"
            ansible-playbook "${SATELLITE_VM_PLAYBOOK}" || exit $?
            update_satellite_ip
            ansible-playbook "${SATELLITE_SERVER_PLAYBOOK}" || exit $?
            satellite_install_msg
        fi
    else
        exit
    fi
}

function qubinode_deploy_satellite () {
    if [ "A${product_maintenance}" != "A" ]
    then
       satellite_server_maintenance
    elif [ "A${teardown}" == "Atrue" ]
    then
        echo "Tear Down Satellite"
        requirements.yml
    else
        qubinode_install_satellite
        qubinode_setup_satellite
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
