# validate the product the user wants to install
function check_ocp_rhsm_pool_id () {
    prereqs
    if [ "A${product_opt}" == "Aocp" ]
    then
        if [ "A${maintenance}" != "Arhsm" ] && [ "A${maintenance}" != "Asetup" ] && [ "A${maintenance}" != "Aclean" ]
        then
            product="${product_opt}"
            if grep '""' "${vars_file}"|grep -q openshift_pool_id
            then
                echo "The OpenShift Pool ID is required."
                echo "Please run: 'qubinode-installer -p ocp -m rhsm' or modify"
                echo "${project_dir}/playbooks/vault/all.yml 'openshift_pool_id'"
                echo "with the pool ID"
                exit 1
            else
                product="${product_opt}"
            fi
        fi
    elif [ "A${product_opt}" == "Aokd" ]
    then
        product="${product_opt}"
    else
      echo "Please pass -p flag for ocp/okd."
      exit 1
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
    if [ "A${product_opt}" != "A" ]
    then
        if [ "A${product_opt}" == "Aocp" ]
        then
            check_for_openshift_subscription
        fi
    fi

    #TODO: this should be change once we start deploy OKD
    if [ "${maintenance}" == "rhsm" ]
    then
      if [ "A${product_opt}" == "Aocp" ]
      then
          check_for_openshift_subscription
      elif [ "A${product_opt}" == "Aokd" ]
      then
          echo "OpenShift Subscription not required"
      else
        echo "Please pass -c flag for ocp/okd."
        exit 1
      fi
    fi

}

function openshift-setup() {
  setup_variables
  if [[ ${product_opt} == "ocp" ]]; then
    sed -i "s/^openshift_deployment_type:.*/openshift_deployment_type: openshift-enterprise/"   "${vars_file}"
  elif [[ ${product_opt} == "okd" ]]; then
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

  if [[ ${product_opt} == "ocp" ]]; then
    cd /usr/share/ansible/openshift-ansible
    ansible-playbook -i  $INVENTORYDIR/inventory.3.11.rhel.gluster playbooks/prerequisites.yml || exit $?
    ansible-playbook -i  $INVENTORYDIR/inventory.3.11.rhel.gluster playbooks/deploy_cluster.yml || exit $?
  elif [[ ${product_opt} == "okd" ]]; then
    echo "Work in Progress"
    exit 1
  fi
}

function qubinode_deploy_openshift () {
    # Teardown the openshift deployment
    if [ "A${teardown}" == "Atrue" ]
    then
        echo "This will delete all nodes and remove all DNS entries"
        confirm "Are you sure you want to undeploy the entire ${product_opt} cluster?"
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
    elif [ "A${product}" == "Atrue" ]
    then
        if [ "A${product_opt}" == "Aocp" ] ||  [ "A${product_opt}" == "Aokd" ]
        then
            echo "Deploying ${product_opt} cluster"
            openshift-setup
        else
           display_help
        fi
    else
        display_help
    fi
}