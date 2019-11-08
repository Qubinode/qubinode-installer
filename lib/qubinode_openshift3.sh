#!/bin/bash

product_in_use: ocp3

function openshift3_config () {
  check_hardware_resources
  echo "REMINDER that this function qubinode_openshift3.sh as this exit that should be removed"
  exit
  if [[ "A${product_opt}" == "Aocp3"  ]]
  then
      bash $generate_all_yaml_script ocp  || exit 1
  elif [[ "A${product_opt}" == "Aokd3"  ]]; then
      bash $generate_all_yaml_script okd  || exit 1
  else
      echo "${product_opt} - Unsupported OpenShift 3 distro"
      echo "ocp3 and okd3 are supported OpenShift 3 distro"
      exit $?
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
    elif [ "A${CONSUMED}" != "A" ]
    then
       echo "Found the repo id: ${CONSUMED} for Red Hat OpenShift Container Platform"
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
                echo "${project_dir}/playbooks/vault/all.yml 'openshift_pool_id'"
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


function openshift-setup() {
  # Does some prep work then runs the official OpenShift ansible playbooks
  setup_variables
  validate_openshift_pool_id
  if [[ ${product_in_use} == "ocp3" ]]; then
    sed -i "s/^openshift_deployment_type:.*/openshift_deployment_type: openshift-enterprise/"   "${vars_file}"
  elif [[ ${product_in_use} == "okd3" ]]; then
    sed -i "s/^openshift_deployment_type:.*/openshift_deployment_type: origin/"   "${vars_file}"
  fi

  if [[ ! -d /usr/share/ansible/openshift-ansible ]]; then
      ansible-playbook "${project_dir}/playbooks/setup_openshift_deployer_node.yml" || exit $?
  fi

  ansible-playbook "${project_dir}/playbooks/openshift_inventory_generator.yml" || exit $?
  INVENTORYDIR=$(cat ${vars_file} | grep inventory_dir: | awk '{print $2}' | tr -d '"')
  cat $INVENTORYDIR/inventory.3.11.rhel.gluster
  HTPASSFILE=$(cat ${INVENTORYDIR}/inventory.3.11.rhel.gluster | grep openshift_master_htpasswd_file= | awk '{print $2}')

  OCUSER=$(cat ${vars_file} | grep openshift_user: | awk '{print $2}')
  if [[ ! -f ${HTPASSFILE} ]]; then
    echo "***************************************"
    echo "Enter pasword to be used by ${OCUSER} user to access openshift console"
    echo "***************************************"
    htpasswd -c ${HTPASSFILE} $OCUSER
  fi

  echo "Running Qubi node openshift deployment checks."
  ansible-playbook -i  $INVENTORYDIR/inventory.3.11.rhel.gluster "${project_dir}/playbooks/pre-deployment-checks.yml" || exit $?

  if [[ ${product_in_use} == "ocp3" ]]; then
    cd /usr/share/ansible/openshift-ansible
    ansible-playbook -i  $INVENTORYDIR/inventory.3.11.rhel.gluster playbooks/prerequisites.yml || exit $?
    ansible-playbook -i  $INVENTORYDIR/inventory.3.11.rhel.gluster playbooks/deploy_cluster.yml || exit $?
  elif [[ ${product_in_use} == "okd3" ]]; then
    echo "Work in Progress"
    exit 1
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

function qubinode_run_openshift_installer () {
    # This function calls the openshift-setup which in turns
    # runs the official openshift ansible playbooks
    # Teardown the openshift deployment

    # ensure subscription is setup for ocp3
    set_openshift_rhsm_pool_id
 
    if [ "A${teardown}" == "Atrue" ]
    then
        echo "This will delete all nodes and remove all DNS entries"
        confirm "Are you sure you want to undeploy the entire ${product_in_use} cluster?"
        if [ "A${response}" == "Ayes" ]
        then
            #qubinode_vm_manager deploy_nodes
            if [[ -f ${HTPASSFILE} ]]; then
                rm -f ${HTPASSFILE}
            fi
        else
            echo "No changes will be made"
            exit
        fi
        # OpenShift Deployment
    elif [ "A${qubinode_product}" == "Atrue" ]
    then
        if [ "A${product_in_use}" == "Aocp3" ] || [ "A${product_in_use}" == "Aokd3" ]
        then
            echo "Deploying ${product_in_use} cluster"
            openshift-setup
        else
           display_help
        fi
    else
        display_help
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

function qubinode_ocp3_nodes_postdeployment () {
   # This functions does post deployment on nodes
   # And it also create DNS records
   # This function is called by are_nodes_deployed
   NODES_POST_PLAY="${project_dir}/playbooks/nodes_post_deployment.yml"
   CHECK_OCP_INVENTORY="${project_dir}/inventory/inventory.3.11.rhel.gluster"
   NODES_DNS_RECORDS="${project_dir}/playbooks/nodes_dns_records.yml"

   if [ "A${teardown}" == "Atrue" ]
   then
       if sudo virsh list |grep -q "${idm_srv_hostname}"
       then
           echo "Remove ${qubinode_product} will be removed"
       fi
   else
       echo "Post configure ${qubinode_product} VMs"
       ansible-playbook "${NODES_DNS_RECORDS}" || exit $?
       ansible-playbook "${NODES_POST_PLAY}" || exit $?
   fi
}


function qubinode_ocp3_nodes () {
   # This functions deploys OpenShift nodes or undeploys them
   # This function is called by are_nodes_deployed
   qubinode_vm_deployment_precheck  #Ensure the host is setup correctly
   NODES_PLAY="${project_dir}/playbooks/deploy_nodes.yml"
   NODES_POST_PLAY="${project_dir}/playbooks/nodes_post_deployment.yml"
   CHECK_OCP_INVENTORY="${project_dir}/inventory/inventory.3.11.rhel.gluster"
   NODES_DNS_RECORDS="${project_dir}/playbooks/nodes_dns_records.yml"

   if [ "A${teardown}" == "Atrue" ]
   then
       if sudo virsh list |grep -q "${idm_srv_hostname}"
       then
           echo "Remove ${qubinode_product} VMs"
           ansible-playbook "${NODES_DNS_RECORDS}" --extra-vars "vm_teardown=true" || exit $?
           ansible-playbook "${NODES_PLAY}" --extra-vars "vm_teardown=true" || exit $?
           if [[ -f ${CHECK_OCP_INVENTORY}  ]]; then
              rm -rf ${CHECK_OCP_INVENTORY}
           fi
       fi
   else
       echo "Deploy ${qubinode_product} VMs"
       ansible-playbook "${NODES_PLAY}" || exit $?
       ansible-playbook "${NODES_POST_PLAY}" || exit $?
   fi
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
   qubinode_ocp3_nodes_postdeployment
}

function qubinode_install_openshift () {
    echo "Ensure ${CURRENT_USER} is in sudoers"
    setup_sudo

    # ensure required variables and files are in place
    product_requirements

    product_in_use=$(awk '/^product:/ {print $2}' "${vars_file}")
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
