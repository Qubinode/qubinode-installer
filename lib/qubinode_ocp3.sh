#!/bin/bash

function validate_openshift_pool_id () {
    # For product Openshift
    if [ "A${product_in_use}" == "Aocp3" ]
    then
        if [ "A${maintenance}" != "Arhsm" ] && [ "A${maintenance}" != "Asetup" ] && [ "A${maintenance}" != "Aclean" ]
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

function check_for_openshift_subscription () {
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

# this function sets the openshift repo id
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
    if [ "${maintenance}" == "rhsm" ]
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
  INVENTORYDIR=$(cat ${project_dir}/playbooks/vars/all.yml | grep inventory_dir: | awk '{print $2}' | tr -d '"')
  cat $INVENTORYDIR/inventory.3.11.rhel.gluster
  HTPASSFILE=$(cat ${INVENTORYDIR}/inventory.3.11.rhel.gluster | grep openshift_master_htpasswd_file= | awk '{print $2}')

  OCUSER=$(cat ${project_dir}/playbooks/vars/all.yml | grep openshift_user: | awk '{print $2}')
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
  INVENTORYDIR=$(cat ${project_dir}/playbooks/vars/all.yml | grep inventory_dir: | awk '{print $2}' | tr -d '"')

  if [[ ${product_in_use} == "ocp3" ]]; then
    ansible-playbook -i  $INVENTORYDIR/inventory.3.11.rhel.gluster    /usr/share/ansible/openshift-ansible/playbooks/adhoc/uninstall.yml || exit $?
  elif [[ ${product_in_use} == "okd3" ]]; then
    echo "Work in Progress"
    exit 1
  fi
}

function qubinode_run_openshift_installer () {
    # This function calls the openshift-setup which in turns
    # runs the official openshift ansible playbooks
    # Teardown the openshift deployment
    if [ "A${teardown}" == "Atrue" ]
    then
        echo "This will delete all nodes and remove all DNS entries"
        confirm "Are you sure you want to undeploy the entire ${product_in_use} cluster?"
        if [ "A${response}" == "Ayes" ]
        then
            qubinode_vm_manager deploy_nodes
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

function qubinode_install_openshift () {
    product_in_use="ocp3"
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
    exit

    printf "\n\n****************************\n"
    printf     "* Deploy VM for DNS server *\n"
    printf     "****************************\n"
    productname=$(cat "${vars_file}"| grep product: | awk '{print $2}' | tr -d '"')
    CHECKFOR_DNS=$(sudo virsh list | grep running | grep ${productname}-dns  | wc -l)
    [[ $CHECKFOR_DNS -eq 0 ]] && qubinode_vm_manager deploy_dns

    printf "\n\n*****************************\n"
    printf     "* Install IDM on DNS server *\n"
    printf     "*****************************\n"
    qubinode_dns_manager server

    printf "\n\n******************************\n"
    printf     "* Deploy Nodes for ${product_in_use} cluster *\n"
    printf     "******************************\n"
    if sudo virsh list|grep -E 'master|node|infra'
    then
        echo "Skipping VM Deployment"
    else
        qubinode_vm_manager deploy_nodes
    fi

    OCUSER=$(cat "${vars_file}" | grep openshift_user: | awk '{print $2}')

    printf "\n\n*********************\n"
    printf     "*Deploy ${product_in_use} cluster *\n"
    printf     "*********************\n"
    qubinode_run_openshift_installer

    printf "\n\n*******************************************************\n"
    printf   "\nDeployment steps for ${product_in_use} cluster is complete.\n"
    printf "\nCluster login: https://ocp-master01.${domain}:8443\n"
    printf "     Username: changeme\n"
    printf "     Password: <yourpassword>\n"
    printf "\n\nIDM DNS Server login: https://ocp-dns01.${domain}\n"
    printf "     Username: admin\n"
    printf "     Password: <yourpassword>\n"
    printf "*******************************************************\n"
}
