#!/bin/bash

openshift3_variables () {
    echo "Loading OpenShift 3 global variables"
    playbooks_dir="${project_dir}/playbooks"
    domain=$(awk '/^domain:/ {print $2}' "${vars_file}")
    prefix=$(awk '/^instance_prefix:/ {print $2}' "${vars_file}")
    product=$(awk '/^openshift_product:/ {print $2}' "${vars_file}")
    productname="${prefix}-${product}"
    web_console="https://${productname}-master01.${domain}:8443"
    ocp_user=$(awk '/^openshift_user:/ {print $2}' "${vars_file}")
    OCUSER=$ocp_user
    product_in_use="${product}"
    ssh_username=$(awk '/^admin_user:/ {print $2}' "${vars_file}")
    libvirt_pool_name=$(awk '/^libvirt_pool_name:/ {print $2}' "${vars_file}")
    NODES_POST_PLAY="${playbooks_dir}/openshift3_nodes_post_deployment.yml"
    NODES_DNS_RECORDS="${playbooks_dir}/openshift3_nodes_dns_records.yml"
    NODES_PLAY="${playbooks_dir}/openshift3_deploy_nodes.yml"
    master_node="${productname}-master01"
    openshift3_pre_deployment_checks_playbook="${playbooks_dir}/openshift3_pre_deployment_checks.yml"
    openshift3_setup_deployer_node_playbook="${playbooks_dir}/openshift3_setup_deployer_node.yml"
    openshift3_inventory_generator_playbook="${playbooks_dir}/openshift3_inventory_generator.yml"
    openshift_ansible_dir=/usr/share/ansible/openshift-ansible

    if ! grep '""' "${vars_file}"|grep -q "openshift_deployment_size:"
    then
        openshift_deployment_size=$(awk '/openshift_deployment_size:/ {print $2}' "${vars_file}")
        openshift_deployment_size_yml="${project_dir}/playbooks/vars/openshift3_size_${openshift_deployment_size}.yml"
        ocp3_vars_files="${project_dir}/playbooks/vars/ocp3.yml ${openshift_deployment_size_yml}"
        okd3_vars_files="${project_dir}/playbooks/vars/okd3.yml ${openshift_deployment_size_yml}"
    fi


    if [ -f "${openshift_deployment_size_yml}" ]
    then
        DEPLOYMENT_SIZE=$(awk '/openshift_deployment_size:/ {print $2}' "${vars_file}")
    fi

    # Set the OpenShift inventory file 
    if ls "${hosts_inventory_dir}/inventory.3.11.rhel*" 1> /dev/null 2>&1
    then
        INVENTORYFILE=$(ls "${hosts_inventory_dir}/inventory.3.11.rhel*")
        HTPASSFILE=$(cat $INVENTORYFILE | grep openshift_master_htpasswd_file= | awk '{print $2}')
    fi
}

function check_openshift3_size_yml () {
    openshift3_variables
    if [ ! -f "${openshift_deployment_size_yml}" ]
    then
        echo "Running Hardware Check"
        check_hardware_resources
    else
        if [ "A${openshift_auto_install}" != "Atrue" ]
        then
            echo ""
            confirm "Continue with a $DEPLOYMENT_SIZE type deployment? yes/no"
            if [ "A${response}" != "Ano" ]
            then
                check_hardware_resources
            fi
        fi
    fi
}

function ask_user_which_openshift_product () {
    if grep '""' "${vars_file}"|grep -q openshift_product:
    then
        echo "We support the following OpenShift deployment options: "
        echo ""
        #echo "   * okd3 - Origin Community Distribution 3"
        echo "   * ocp3 - Red Hat OpenShift Container Platform 3"
        #echo "   * ocp4 - Red Hat OpenShift Container Platform 4"
        echo ""

        echo "Select one of the options below to deploy : "
        #ocp_product_msg=("ocp3" "ocp4" "okd3")
        ocp_product_msg=("ocp3")
        createmenu "${ocp_product_msg[@]}"
        openshift_product=($(echo "${selected_option}"))
        update_variable=true
    else
        openshift_product=$(awk '/openshift_product:/ {print $2}' "${vars_file}")
        update_variable=false
    fi

    if [ "A${teardown}" != "Atrue" ]
    then
        if [ "A${openshift_auto_install}" == "Atrue" ]
        then
            set_openshift_production_variables
        else
            confirm "Continue with OpenShift version: ${openshift_product}? yes/no"
            if [ "A${response}" == "Ayes" ]
            then
                set_openshift_production_variables
            else
                ask_user_which_openshift_product
            fi
        fi
    fi
}

function set_openshift_production_variables () {
    if [ "A${update_variable}" == "Atrue" ]
    then
        echo "Setting OpenShift version to ${openshift_product}"
        sed -i "s/openshift_product:.*/openshift_product: "$openshift_product"/g" "${vars_file}"
        if [[ ${openshift_product} == "ocp3" ]]
        then
            # ensure we are deploying openshift enterprise
            sed -i "s/^openshift_deployment_type:.*/openshift_deployment_type: openshift-enterprise/"   "${vars_file}"
        elif [[ ${openshift_product} == "okd3" ]]
        then
            sed -i "s/^openshift_deployment_type:.*/openshift_deployment_type: origin/"   "${vars_file}"
        else
            echo "Unsupported OpenShift distro"
            exit 1
        fi
    else
        echo "OpenShift version is set to ${openshift_product}"
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
       if [ ! -f "${openshift_deployment_size_yml}" ]
       then
           echo "Running check_openshift3_size_yml"
           check_openshift3_size_yml
       fi 
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
      
       echo "Attaching system Red Hat OpenShift Container Platform subscription pool"
       sudo subscription-manager remove --all
       sudo subscription-manager attach --pool="${POOL_ID}"
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


function qubinode_deploy_openshift () {
    # Load function variables
    setup_variables
    openshift3_variables

    # Load functions
    qubinode_rhsm_register  # ensure system is registered
    validate_openshift_pool_id # ensure it's attached to the ocp pool
    check_openshift3_size_yml # ensure ocp size yaml is generated

    # Check for openshift user
    if grep '""' "${vars_file}"|grep -q openshift_user
    then
        echo "Setting openshift_user variable to $CURRENT_USER in ${vars_file}"
        sed -i "s#openshift_user:.*#openshift_user: "$CURRENT_USER"#g" "${vars_file}"
    else
        echo "Could not determine the openshift_user variable, please resolve and try again"
        exit 1
    fi

    # ensure KVMHOST is setup as a jumpbox
    if [[ ! -d "${openshift_ansible_dir}" ]]
    then
        run_cmd="ansible-playbook ${openshift3_setup_deployer_node_playbook}"
        $run_cmd || exit_status "$run_cmd" $LINENf [[ ${product_in_use} == "okd3" ]]
O
    else
        echo "Could not find ${openshift_ansible_dir}"
        echo "Ensure the openshift installer is installed and try again."
        exit 1
    fi

    # Generate the openshift inventory
    run_cmd="ansible-playbook ${openshift3_inventory_generator_playbook}"
    $run_cmd || exit_status "$run_cmd" $LINENO
    # Set the OpenShift inventory file 
    if ls "${hosts_inventory_dir}/inventory.3.11.rhel*" 1> /dev/null 2>&1
    then
        INVENTORYFILE=$(ls "${hosts_inventory_dir}/inventory.3.11.rhel*")
        HTPASSFILE=$(cat $INVENTORYFILE | grep openshift_master_htpasswd_file= | awk '{print $2}')
    else
        echo "Could not file the openshift inventory file under ${hosts_inventory_dir}/inventory.3.11.rhel*"
        exit 1
    fi

    # Ensure the inventory file exists
    if [ ! -f "${INVENTORYFILE}" ]
    then
        echo "Installation aborted: cannot find the inventory file ${INVENTORYFILE}"
        exit
    fi
    
    # run openshift pre deployment checks
    echo "Running Qubi node openshift deployment checks."
    run_cmd="ansible-playbook -i ${INVENTORYFILE} ${openshift3_pre_deployment_checks_playbook}"
    $run_cmd || exit_status "$run_cmd" $LINENO

    # ensure htpassword file is created and populated
    if [[ ! -f ${HTPASSFILE} ]]; then
        get_admin_user_password
        run_cmd="htpasswd -b ${HTPASSFILE} $OCUSER $admin_user_passowrd"
        $run_cmd || exit_status "$run_cmd" $LINENO
    fi


    # run openshift installation 
    if [[ ${product_in_use} == "ocp3" ]]
    then
        cd "${openshift_ansible_dir}"
        run_cmd="ansible-playbook -i $INVENTORYFILE playbooks/prerequisites.yml"
        $run_cmd || exit_status "$run_cmd" $LINENO

        run_cmd="ansible-playbook -i $INVENTORYFILE playbooks/deploy_cluster.yml"
        $run_cmd || exit_status "$run_cmd" $LINENO
    elif [[ ${product_in_use} == "okd3" ]]
    then
        cd ${HOME}/openshift-ansible
        ansible-playbook -i  $INVENTORYFILE playbooks/prerequisites.yml || exit $?
        ansible-playbook -i  $INVENTORYFILE playbooks/deploy_cluster.yml || exit $?
    fi
}

function qubinode_uninstall_openshift() {
  openshift3_variables
  if [[ ${product_in_use} == "ocp3" ]]; then
    ansible-playbook -i  "${INVENTORYFILE}" "${openshift_ansible_uninstall_playbook}" || exit $?
  elif [[ ${product_in_use} == "okd3" ]]; then
    echo "Work in Progress"
    exit 1
  fi
}


function qubinode_teardown_cleanup () {
    openshift3_variables
    # Remove DNS entries
    test -f "${INVENTORYFILE}" && rm -f "${INVENTORYFILE}"

    if [[ -f "${INVENTORYFILE}"  ]]; then
        rm -rf "${INVENTORYFILE}"
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
        # Remove DNS entries
        if sudo virsh list |grep -q "${idm_srv_hostname}"
        then
            echo "Remove ${openshift_product} VMs"
            ansible-playbook "${NODES_DNS_RECORDS}" --extra-vars "vm_teardown=true"
        fi

        # Remove VMs and files
        master="${productname}-master01"
        node="${productname}-node01"
        infra="${productname}-infra01"
        if sudo virsh list | grep -q "'${master}\|${node}\|${infra}'"
        then
            ansible-playbook "${NODES_PLAY}" --extra-vars "vm_teardown=true" || exit $?
            qubinode_teardown_cleanup
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


function qubinode_autoinstall_openshift () {
    echo "Ensure ${CURRENT_USER} is in sudoers"
    setup_sudoers
    product_in_use="ocp3"

    printf "\n\n***********************\n"
    printf "* Running perquisites *\n"
    printf "***********************\n\n"
    qubinode_installer_setup

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
    qubinode_setup_kvm_host

    printf "\n\n****************************\n"
    printf     "* Deploy IdM DNS Server    *\n"
    printf     "****************************\n"
    qubinode_deploy_idm

    printf "\n\n*********************\n"
    printf     "*Deploy ${product_in_use} cluster *\n"
    printf     "*********************\n"
    openshift_auto_install=true
    sed -i "s/openshift_auto_install:.*/openshift_auto_install: "$openshift_auto_install"/g" "${vars_file}"
    openshift_enterprise_deployment
    report_on_openshift3_installation
}

function are_openshift_nodes_available () {
    ansible qbnodes -m ping 2>&1 | tee /tmp/fail >/dev/null
    TOTAL_FAILED_HOST=0
    TOTAL_HOST=0
    while read line
    do
        HOST=$(echo $line | awk '/=>/ {print $1}')
        STATUS=$(echo $line | awk '/=>/ {print $3}')

        if [ "A${HOST}" != "A" ]
        then
            TOTAL_HOST=$(expr $TOTAL_HOST + 1)
        fi

        if [ "A${STATUS}" == "AUNREACHABLE!" ]
        then
            TOTAL_FAILED_HOST=$(expr $TOTAL_FAILED_HOST + 1)
            echo "$HOST status is $STATUS"
        fi
    done < /tmp/fail

    if [ "A${TOTAL_HOST}" != "A0" ]
    then
        if [ "A${TOTAL_FAILED_HOST}" != "A0" ]
        then
            echo "$TOTAL_FAILED_HOST of the $TOTAL_HOST OpenShift nodes failed"
            exit 1
        fi
    fi

    if [ "A${TOTAL_HOST}" == "A0" ]
    then
        echo "$TOTAL_HOST available attempting to deploy openshift nodes"
        qubinode_openshift_nodes
    else
        echo "All ${TOTAL_HOST} OpenShift nodes are available"
    fi
}

function maintenance_deploy_nodes () {
    # This is a wrapper function to deploy openshift nodes
    # via the -m deploy_nodes argument
    ask_user_which_openshift_product
    qubinode_openshift_nodes

    if [ "A${teardown}" != "Atrue" ]
    then
        printf "\n\n**************************************\n"
        printf "* Nodes for OpenShift Cluster deployed  *\n"
        printf "****************************************\n\n"
    else
        printf "\n\n**************************************\n"
        printf "* Nodes for OpenShift Cluster deleted   *\n"
        printf "****************************************\n\n"
    fi
}

function openshift_enterprise_deployment () {
    # This is a wrapper function to deploy openshift nodes
    # via the -m deploy_nodes argument
    openshift_product=ocp3
    sed -i "s/openshift_product:.*/openshift_product: "$openshift_product"/g" "${vars_file}"
    ask_user_which_openshift_product
    are_openshift_nodes_available
    qubinode_deploy_openshift
    report_on_openshift3_installation
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

function openshift3_server_maintenance () {
    case ${product_maintenance} in
        diag)
            echo "Perparing to run full Diagnostics"
            MASTER_NODE=$(cat "${project_dir}/inventory/hosts" | grep "master01" | awk '{print $1}')
            ssh -t  -o "StrictHostKeyChecking=no" $MASTER_NODE "sudo oadm diagnostics"
            ;;
        smoketest)
            echo  "Running smoke test on environment."
            bash "${project_dir}/lib/openshift-smoke-test.sh" || exit $?
            ;;
        shutdown)
            echo  "Shutting down cluster"
            openshift3_cluster_shutdown halt
            ;;
        startup)
            echo  "Starting up Cluster"
            openshift3_cluster_startup running
            ;;
        checkcluster)
            echo  "Running Cluster health check"
            MASTER_NODE=$(cat "${project_dir}/inventory/hosts" | grep "master01" | awk '{print $1}')
            ssh -t  -o "StrictHostKeyChecking=no" $MASTER_NODE 'bash -s' < "${CHECK_STATE_CMD}" both
            ;;
        *)
            echo "No arguement was passed"
            ;;
    esac
}


function report_on_openshift3_installation () {
  # load openshift variables
  openshift3_variables

    if sudo virsh list|grep -E 'master|node|infra'
    then
        echo "Checking to see if Openshift is online."
        OCP_STATUS=$(curl --write-out %{http_code} --silent --output /dev/null " ${web_console}" --insecure)
        if [[ $OCP_STATUS -eq 200 ]];  then
            openshift3_installation_msg
            exit 0
        else
            CHECKFOROCP=$(sudo virsh list|grep -E "'${productname}-master'" | awk '{print $2}')
            if [[ $CHECKFOROCP == "${productname}-master01" ]]; then
                if [[ ${productname} == "okd" ]]; then
                    echo "Please destroy running OpenShift Enterprise VMs before continuing to install OpenShift Origin."
                    echo "********************************************"
                    echo "1. ./qubinode-installer -p ocp -d or ./qubinode-installer -p ocp -m deploy_nodes -d "
                    echo "2. ./qubinode-installer -p idm -d "
                    echo "3. ./qubinode-installer -p ocp -m clean "
                    echo "restart ./qubinode-installer option 2"
                    exit 1
                fi
            fi
            echo  "FAILED to connect to Openshift Console URL:  ${web_console}"
            printf "\n\n*********************\n"
        fi
    fi
}

function openshift3_installation_msg () {
    # load openshift variables
    openshift3_variables

    printf "\n\n*******************************************************\n"
    printf "\nDeployment steps for ${product} cluster is complete.\n"
    printf "\nCluster login: ${web_console}\n"
    printf "     Username: ${OCUSER}\n"
    printf "     Password: <yourpassword>\n"
    printf "\n\nIDM DNS Server login: https://${prefix}-dns01.${domain}\n"
    printf "     Username: admin\n"
    printf "     Password: <yourpassword>\n"
    printf "*******************************************************\n"
}

