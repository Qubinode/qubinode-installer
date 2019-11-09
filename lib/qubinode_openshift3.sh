#!/bin/bash

openshift3_variables () {
    playbooks_dir="${project_dir}/playbooks"
    domain=$(awk '/^domain:/ {print $2}' "${vars_file}")
    prefix=$(awk '/^instance_prefix:/ {print $2}' "${vars_file}")
    product=$(awk '/^openshift_product:/ {print $2}' "${vars_file}")
    productname="${prefix}-${product}"
    web_console="https://${productname}-master01.${domain}:8443"
    ocp_user=$(awk '/^openshift_user:/ {print $2}' "${vars_file}")
    product_in_use="${product}"
    ssh_username=$(awk '/^admin_user:/ {print $2}' "${vars_file}")
    libvirt_pool_name=$(awk '/^libvirt_pool_name:/ {print $2}' "${vars_file}")
    NODES_POST_PLAY="${playbooks_dir}/openshift3_nodes_post_deployment.yml"
    CHECK_OCP_INVENTORY="${project_dir}/inventory/inventory.3.11.rhel.gluster"
    NODES_DNS_RECORDS="${playbooks_dir}/openshift3_nodes_dns_records.yml"
    NODES_PLAY="${playbooks_dir}/openshift3_deploy_nodes.yml"
    DEPLOYMENT_TYPE=$(awk '/deployment_type:/ {print $2}' "${playbooks_dir}/vars/openshift3_size.yml")

}

function check_openshift3_size_yml () {
    openshift3_variables
    if [ -f "${playbooks_dir}/vars/openshift3_size.yml" ]
    then
        echo ""
        echo ""
        confirm "Continue with a $DEPLOYMENT_TYPE type deployment? yes/no"
        if [ "A${response}" != "Ayes" ]
        then
            check_hardware_resources
        fi
    else
        check_hardware_resources
    fi
}

function ask_user_which_openshift_product () {
    if grep '""' "${vars_file}"|grep -q openshift_product:
    then
        echo "We support the following OpenShift deployment options: "
        echo ""
        echo "   * okd3 - Origin Community Distribution 3"
        echo "   * ocp3 - Red Hat OpenShift Container Platform 3"
        echo "   * ocp4 - Red Hat OpenShift Container Platform 4"
        echo ""

        echo "Select one of the options below to deploy : "
        ocp_product_msg=("ocp3" "ocp4" "okd3")
        createmenu "${ocp_product_msg[@]}"
        openshift_product=($(echo "${selected_option}"))
        update_variable=true
    else
        openshift_product=$(awk '/openshift_product:/ {print $2}' "${vars_file}")
        update_variable=false
    fi

    if [ "A${teardown}" != "Atrue" ]
    then
        confirm "Continue with OpenShift version: ${openshift_product}? yes/no"
        if [ "A${response}" == "Ayes" ]
        then
            if [ "A${update_variable}" == "Atrue" ]
            then
                echo "Setting OpenShift version to ${openshift_product}"
                sed -i "s/openshift_product:.*/openshift_product: "$openshift_product"/g" "${vars_file}"
            else
                echo "OpenShift version is set to ${openshift_product}"
            fi
        else
            ask_user_which_openshift_product
        fi
    fi
}

function qubinode_openshift3_nodes_postdeployment () {
   # This functions does post deployment on nodes
   # And it also create DNS records
   # This function is called by are_nodes_deployed

   # load openshift variables function
   openshift3_variables

   if [ "A${teardown}" == "Atrue" ]
   then
       if sudo virsh list |grep -q "${idm_srv_hostname}"
       then
           echo "Remove ${openshift_product} will be removed"
       fi
   else
       echo "Post configure ${openshift_product} VMs"
       ansible-playbook "${NODES_DNS_RECORDS}" || exit $?
       ansible-playbook "${NODES_POST_PLAY}" || exit $?
   fi
}

function qubinode_openshift_nodes () {
   # This functions deploys OpenShift nodes or undeploys them
   # This function is called by are_nodes_deployed
   qubinode_vm_deployment_precheck  #Ensure the host is setup correctly
   openshift3_variables
   check_for_required_role deploy-kvm-vm

   if [ "A${teardown}" == "Atrue" ]
   then
       qubinode_teardown_openshift
   elif [ "A${teardown}" != "Atrue" ]
   then
       check_openshift3_size_yml
       echo "Deploy ${openshift_product} VMs"
       ansible-playbook "${NODES_PLAY}" || exit $?
       ansible-playbook "${NODES_POST_PLAY}" || exit $?
   fi
}


function check_for_openshift_subscription () {
    # This function trys to find a subscription that mataches the OpenShift product
    # then saves the pool id for that function and updates the varaibles file.
    AVAILABLE=$(sudo subscription-manager list --available --matches 'Red Hat OpenShift Container Platform' | grep Pool | awk '{print $3}' | head -n 1)
    CONSUMED=$(sudo subscription-manager list --consumed --matches 'Red Hat OpenShift Container Platform' --pool-only)

    if [ "A${CONSUMED}" != "A" ]
    then
       echo "The system is already attached to the Red Hat OpenShift Container Platform with pool id: ${CONSUMED}"
       POOL_ID="${CONSUMED}"
    elif [ "A${CONSUMED}" == "A" ]
    then
       echo "Found the repo id: ${AVAILABLE} for Red Hat OpenShift Container Platform"
       POOL_ID="${AVAILABLE}"
    else
        cat "${project_dir}/docs/subscription_pool_message"
        exit 1
    fi

    # set subscription pool id
    if [ "A${POOL_ID}" != "A" ]
    then
        echo "Setting pool id for OpenShift Container Platform"
        if grep '""' "${vars_file}"|grep -q openshift_pool_id
        then
            echo "${vars_file} openshift_pool_id variable"
            sed -i "s/openshift_pool_id: \"\"/openshift_pool_id: $POOL_ID/g" "${vars_file}"
        fi
    else
        echo "The OpenShift Pool ID is not available to playbooks/vars/all.yml"
    fi
}

function validate_openshift_pool_id () {
    # This function ensures that when installing OCP
    # There exist an OpenShift subscription and an avialable pool id
    # it calls the function check_for_openshift_subscription
    if [ "A${product_in_use}" == "Aocp3" ]
    then
        if [ "A${qubinode_maintenance_opt}" != "Arhsm" ] && [ "A${qubinode_maintenance_opt}" != "Asetup" ] && [ "A${qubinode_maintenance_opt}" != "Aclean" ]
        then
            check_for_openshift_subscription
            if grep '""' "${vars_file}"|grep -q openshift_pool_id
            then
                echo "The OpenShift Pool ID is required."
                echo "Please run: 'qubinode-installer -p ocp3 -m rhsm' or modify"
                echo "${playbooks_dir}/vault/all.yml 'openshift_pool_id'"
                echo "with the pool ID"
                exit 1
            fi
        fi
    fi
}

# NOTE: This function may be redudant and probable should be removed
function set_openshift_rhsm_pool_id () {
    # set subscription pool id
    if [ "A${product_in_use}" != "A" ]
    then
        if [ "A${product_in_use}" == "Aocp3" ]
        then
            check_for_openshift_subscription
        fi
    fi

    #TODO: this should be change once we start deploy OKD
    if [ "${qubinode_maintenance_opt}" == "rhsm" ]
    then
      if [ "A${product_in_use}" == "Aocp3" ]
      then
          check_for_openshift_subscription
      elif [ "A${product_in_use}" == "Aokd3" ]
      then
          echo "OpenShift Subscription not required"
      else
        echo "Please pass -c flag for ocp3/okd3."
        exit 1
      fi
    fi

}


function qubinode_deploy_openshift() {
  # Does some prep work then runs the official OpenShift ansible playbooks
  setup_variables
  validate_openshift_pool_id
  if [[ ${product_in_use} == "ocp3" ]]
  then
     # ensure we are deploying openshift enterprise
     sed -i "s/^openshift_deployment_type:.*/openshift_deployment_type: openshift-enterprise/"   "${vars_file}"
  elif [[ ${product_in_use} == "okd3" ]]
  then
      sed -i "s/^openshift_deployment_type:.*/openshift_deployment_type: origin/"   "${vars_file}"
  else
      echo "Unsupported OpenShift distro"
      exit 1
  fi

  # ensure KVMHOST is setup as a jumpbox
  if [[ ! -d /usr/share/ansible/openshift-ansible ]]
  then
      ansible-playbook "${playbooks_dir}/openshift3_setup_deployer_node.yml" || exit $?
  fi

  ansible-playbook "${playbooks_dir}/openshift3_inventory_generator.yml" || exit $?
  exit
  INVENTORYDIR=$(cat ${vars_file} | grep inventory_dir: | awk '{print $2}' | tr -d '"')
  INVENTORYFILE=$(ls $INVENTORYDIR/inventory.3.11.rhel.*)
  cat $INVENTORYFILE || exit 1
  HTPASSFILE=$(cat $INVENTORYFILE | grep openshift_master_htpasswd_file= | awk '{print $2}')

  OCUSER=$(cat ${vars_file} | grep openshift_user: | awk '{print $2}')
  if [[ ! -f ${HTPASSFILE} ]]; then
    echo "***************************************"
    echo "Enter pasword to be used by ${OCUSER} user to access openshift console"
    echo "***************************************"
    htpasswd -c ${HTPASSFILE} $OCUSER
  fi

  echo "Running Qubi node openshift deployment checks."
  ansible-playbook -i  $INVENTORYDIR/inventory.3.11.rhel.gluster "${playbooks_dir}/openshift3_pre_deployment_checks.yml" || exit $?

  if [[ ${product_in_use} == "ocp3" ]]
  then
      cd /usr/share/ansible/openshift-ansible
      ansible-playbook -i  $INVENTORYFILE playbooks/prerequisites.yml || exit $?
      ansible-playbook -i  $INVENTORYFILE playbooks/deploy_cluster.yml || exit $?
  elif [[ ${product_in_use} == "okd3" ]]
  then
      cd ${HOME}/openshift-ansible
      ansible-playbook -i  $INVENTORYFILE playbooks/prerequisites.yml || exit $?
      ansible-playbook -i  $INVENTORYFILE playbooks/deploy_cluster.yml || exit $?
  fi
}

function qubinode_uninstall_openshift() {
  INVENTORYDIR=$(cat ${vars_file} | grep inventory_dir: | awk '{print $2}' | tr -d '"')

  if [[ ${product_in_use} == "ocp3" ]]; then
    ansible-playbook -i  $INVENTORYDIR/inventory.3.11.rhel.gluster /usr/share/ansible/openshift-ansible/playbooks/adhoc/uninstall.yml || exit $?
  elif [[ ${product_in_use} == "okd3" ]]; then
    echo "Work in Progress"
    exit 1
  fi
}


function qubinode_teardown_cleanup () {
        # Remove DNS entries
        if sudo virsh list |grep -q "${idm_srv_hostname}"
        then
            echo "Remove ${openshift_product} VMs"
            ansible-playbook "${NODES_DNS_RECORDS}" --extra-vars "vm_teardown=true"
        fi
    
        if [[ -f ${CHECK_OCP_INVENTORY}  ]]; then
            rm -rf ${CHECK_OCP_INVENTORY}
        fi

        # Remove ocp3 yml files    
        if [ "A${product}" == "Aocp3" ]
        then
            for file in $(echo ${ocp3_vars_files})
            do
                test -f $file && rm -f $file
            done
        fi

        # Remove okd3 yml files    
        if [ "A${product}" == "Aokd3" ]
        then
            for file in $(echo ${okd3_vars_files})
            do
                test -f $file && rm -f $file
            done
        fi
}

function qubinode_teardown_openshift () {
    openshift3_variables
    echo ""
    echo ""
    echo "This will delete all nodes and remove all DNS entries"
    echo ""
    confirm "Are you sure you want to undeploy the entire ${product_in_use} cluster? yes/no"
    if [ "A${response}" == "Ayes" ]
    then

        # Remove VMs and files
        master="${productname}-master01"
        node="${productname}-node01"
        infra="${productname}-infra01"
        if sudo virsh list | grep -q "'${master}\|${node}\|${infra}'"
        then
            ansible-playbook "${NODES_PLAY}" --extra-vars "vm_teardown=true" || exit $?
        elif ! sudo virsh list | grep -q "'${master}\|${node}\|${infra}'"
        then
            qubinode_teardown_cleanup
        else
            qubinode_teardown_cleanup
        fi
    else
        echo "No changes will be made"
        exit
    fi
}


function cleanStaleKnownHost () {
    user=$1
    host=$2
    alt_host_name=$3
    isKnownHostStale=$(ssh -o connecttimeout=2 -o stricthostkeychecking=no ${user}@${host} true 2>&1|grep -c "Offending")
    if [ "A${isKnownHostStale}" == "A1" ]
    then
        ssh-keygen -R ${host}
        if [ "A${alt_host_name}" != "A" ]
        then
            ssh-keygen -R ${alt_host_name} >/dev/null 2>&1
        fi
    fi
}

function canSSH () {
    user=$1
    host=$2
    RESULT=$(ssh -q -o StrictHostKeyChecking=no -o "BatchMode=yes" -i /home/${user}/.ssh/id_rsa "${user}@${host}" "echo 2>&1" && echo SSH_OK || echo SSH_NOK)
    echo $RESULT
}


function qubinode_install_openshift () {
    echo "Ensure ${CURRENT_USER} is in sudoers"
    setup_sudo

    # ensure required variables and files are in place
    product_requirements

    qubinode_product=true
    printf "\n\n***********************\n"
    printf "* Running perquisites *\n"
    printf "***********************\n\n"
    qubinode_installer_preflight

    printf "\n\n********************************************\n"
    printf "* Ensure host system is registered to RHSM *\n"
    printf "*********************************************\n\n"
    qubinode_rhsm_register

    printf "\n\n*******************************************************\n"
    printf "* Ensure host system is setup as a ansible controller *\n"
    printf "*******************************************************\n\n"
    test ! -f /usr/bin/ansible && qubinode_setup_ansible

    printf "\n\n*********************************************\n"
    printf     "* Ensure host system is setup as a KVM host *\n"
    printf     "*********************************************\n"
    qubinode_check_kvmhost

    printf "\n\n****************************\n"
    printf     "* Deploy VM for DNS server *\n"
    printf     "****************************\n"
    qubinode_deploy_idm_vm

    printf "\n\n*****************************\n"
    printf     "* Install IDM on DNS VM*\n"
    printf     "*****************************\n"
    if ! curl -k -s "https://${idm_srv_hostname}/ipa/config/ca.crt" > /dev/null
    then
        qubinode_deploy_idm
    fi

    printf "\n\n******************************\n"
    printf     "* Deploy Nodes for ${product_in_use} cluster *\n"
    printf     "******************************\n"
    are_nodes_deployed

    OCUSER=$(cat "${vars_file}" | grep openshift_user: | awk '{print $2}')

    printf "\n\n*********************\n"
    printf     "*Deploy ${product_in_use} cluster *\n"
    printf     "*********************\n"
    qubinode_run_openshift_installer
    OCP3_HOSTNAME=$(awk '/master01/ {print $1}' ${project_dir}/inventory/hosts)
    DNS_SRV=$(awk '/dns01/ {print $1}' ${project_dir}/inventory/hosts)

    printf "\n\n*******************************************************\n"
    printf   "\nDeployment steps for ${product_in_use} cluster is complete.\n"
    printf "\nCluster login: https://${OCP3_HOSTNAME}.${domain}:8443\n"
    printf "     Username: changeme\n"
    printf "     Password: <yourpassword>\n"
    printf "\n\nIDM DNS Server login: https://${DNS_SRV}.${domain}\n"
    printf "     Username: admin\n"
    printf "     Password: <yourpassword>\n"
    printf "*******************************************************\n"
}

function maintenance_deploy_nodes () {
    # This is a wrapper function to deploy openshift nodes
    # via the -m deploy_nodes argument
    ask_user_which_openshift_product
    qubinode_openshift_nodes
}

function are_nodes_deployed () {
    nodes_list="${VM_DATA_DIR}/nodes_list.txt"
    if [ -f "${nodes_list}" ]
    then
        for node in $(cat "${nodes_list}")
        do
            if sudo virsh list |grep running |grep -q $node
            then
                IP=$(awk -v var="${node}" '$0 ~ var {print $0}' "${project_dir}/inventory/hosts"|grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
                cleanStaleKnownHost "${ADMIN_USER}" "${IP}" "${node}"
                ssh_status=$(canSSH "${ADMIN_USER}" "${IP}")
                if [ "A${ssh_status}" == "ASSH_OK" ]
                then
                    echo "node $node VM is already deployed and ssh accessible"
                else
                    echo "Run deploy code"
                    break
                fi

            else
                echo "node $node VM is not running"
                run_node_deploy=yes
                break
            fi
        done

   fi

   if [ "A${run_nodes_deploy}" == "Ayes" ]
   then
       qubinode_deploy_ocp3
   fi

   # Run post deployment
   qubinode_openshift3_nodes_postdeployment
}

