#!/bin/bash

function openshift3_variables () {
    # This function is a catch all for all
    # global variables used used in this script
    # for ocp3.

    playbooks_dir="${project_dir}/playbooks"
    vars_file="${playbooks_dir}/vars/all.yml"
    ocp3_vars_file="${playbooks_dir}/vars/ocp3.yml"
    idm_vars_file="${playbooks_dir}/vars/idm.yml"
    domain=$(awk '/^domain:/ {print $2}' "${vars_file}")
    prefix=$(awk '/^instance_prefix:/ {print $2}' "${vars_file}")
    product=$(awk '/^openshift_product:/ {print $2}' "${ocp3_vars_file}")
    productname="${prefix}-${product}"
    web_console="https://${productname}-master01.${domain}:8443"
    ocp_user=$(awk '/^openshift_user:/ {print $2}' "${ocp3_vars_file}")
    OCUSER=$ocp_user
    product_in_use="${product}"
    ssh_username=$(awk '/^admin_user:/ {print $2}' "${vars_file}")
    libvirt_pool_name=$(awk '/^libvirt_pool_name:/ {print $2}' "${vars_file}")
    NODES_POST_PLAY="${playbooks_dir}/openshift3_nodes_post_deployment.yml"
    NODES_DNS_RECORDS="${playbooks_dir}/openshift3_nodes_dns_records.yml"
    NODES_PLAY="${playbooks_dir}/openshift3_deploy_nodes.yml"
    master_node="${productname}-master01"
    openshift3_pre_deployment_checks_playbook="${playbooks_dir}/openshift3_pre_deployment_checks.yml"
    openshift3_post_deployment_checks_playbook="${playbooks_dir}/openshift3_post_deployment_checks.yml"
    openshift3_setup_deployer_node_playbook="${playbooks_dir}/openshift3_setup_deployer_node.yml"
    openshift3_inventory_generator_playbook="${playbooks_dir}/openshift3_inventory_generator.yml"
    openshift_ansible_dir=/usr/share/ansible/openshift-ansible

    # The the defined cluster size to deploy
    if ! grep '""' "${ocp3_vars_file}"|grep -q "openshift_deployment_size:"
    then
        openshift_deployment_size=$(awk '/openshift_deployment_size:/ {print $2}' "${ocp3_vars_file}")
        openshift_deployment_size_yml="${project_dir}/playbooks/vars/openshift3_size_${openshift_deployment_size}.yml"
        ocp3_ocp3_vars_files="${project_dir}/playbooks/vars/ocp3.yml ${openshift_deployment_size_yml}"
        okd3_ocp3_vars_files="${project_dir}/playbooks/vars/okd3.yml ${openshift_deployment_size_yml}"
    fi


    if [ -f "${openshift_deployment_size_yml}" ]
    then
        DEPLOYMENT_SIZE=$(awk '/openshift_deployment_size:/ {print $2}' "${ocp3_vars_file}")
    fi

    # Set the OpenShift inventory file
    OCP_INVENTORY=$(find "${hosts_inventory_dir}" -name inventory.3.11.rhel* -print)
    if [ "A${OCP_INVENTORY}" != "A" ]
    then
        INVENTORYFILE="${OCP_INVENTORY}"
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
            if [ "A${response}" != "Ayes" ]
            then
                check_hardware_resources
            fi
        fi
    fi
}

function ask_user_which_openshift_product () {
    if grep '""' "${ocp3_vars_file}"|grep -q openshift_product:
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
        openshift_product=$(awk '/openshift_product:/ {print $2}' "${ocp3_vars_file}")
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
                accept_ocp3_build
                set_openshift_production_variables
            else
                ask_user_which_openshift_product
            fi
        fi
    fi
}

function accept_ocp3_build() {
    validateinstall=$(cat  "${project_dir}/playbooks/vars/ocp3.yml" | grep accept_openshift_release | awk '{print $2}')
    if [[ ${validateinstall} == "false" ]]
    then
        currentbuild=$(cat  "${project_dir}/playbooks/vars/ocp3.yml" | grep openshift_image_tag | awk '{print $2}')
        echo "Current OpenShift build defined in Qubinode Installer is ${currentbuild}"
        echo "It is highly recommened to review the link below before installation."
        echo "Link: https://docs.openshift.com/container-platform/3.11/release_notes/ocp_3_11_release_notes.html "

        confirm "Continue with OpenShift Build: ${currentbuild} yes/no"
        if [ "A${response}" == "Ayes" ]
        then
            sed -i "s/^validateinstall:.*/validateinstall: true/"   "${project_dir}/playbooks/vars/ocp3.yml"
        else
            read -p 'Enter OpenShift Build Number Example (3.11.153): ' newbuild
            if [[ "${newbuild}" =~ ^3.11.[0-9][0-9][0-9]$ ]]; then
              sed -i "s/^openshift_image_tag:.*/openshift_image_tag: v${newbuild}/"   "${project_dir}/playbooks/vars/ocp3.yml"
              sed -i "s/^validateinstall:.*/validateinstall: -${newbuild}/"   "${project_dir}/playbooks/vars/ocp3.yml"
            fi
        fi
    fi
}

function set_openshift_production_variables () {
    echo "Running set_openshift_production_variables"
    # This functions set the openshift install to ocp3 or okd3

    if [ "A${update_variable}" == "Atrue" ]
    then
        echo "Setting OpenShift version to ${openshift_product}"
        sed -i "s/openshift_product:.*/openshift_product: "$openshift_product"/g" "${vars_file}"
        sed -i "s/openshift_deployment_type:.*/openshift_deployment_type: openshift-enterprise/g" "${ocp3_vars_file}"
        if [[ ${openshift_product} == "ocp3" ]]
        then
            # ensure we are deploying openshift enterprise
            sed -i "s/^openshift_deployment_type:.*/openshift_deployment_type: openshift-enterprise/"   "${ocp3_vars_file}"
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
       # Run node post deployment check playbook
       ansible-playbook ${openshift3_post_deployment_checks_playbook}

       # Ensure DNS records and the post deploy playboo is executed
       # Web cluster status is not up
       if [ "A${STATUS}" !=  "A200" ] ; then
           ansible-playbook "${NODES_DNS_RECORDS}" || exit $?
           ansible-playbook "${NODES_POST_PLAY}" || exit $?
       fi
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
       #ansible-playbook "${NODES_POST_PLAY}" || exit $?
       qubinode_openshift3_nodes_postdeployment
   fi

   if [ "A${teardown}" != "Atrue" ]
   then
       printf "\n\n**************************************\n"
       printf "* Nodes for OpenShift Cluster deployed  *\n"
       printf "*****************************************\n\n"
   else
       printf "\n\n*****************************************\n"
       printf "* Nodes for OpenShift Cluster deleted   *\n"
       printf "*****************************************\n\n"
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
        if grep '""' "${ocp3_vars_file}"|grep -q openshift_pool_id
        then
            echo "${ocp3_vars_file} openshift_pool_id variable"
            sed -i "s/openshift_pool_id: \"\"/openshift_pool_id: $POOL_ID/g" "${ocp3_vars_file}"
        fi
    else
        echo "The OpenShift Pool ID is not available to playbooks/vars/ocp3.yml"
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
            if grep '""' "${ocp3_vars_file}"|grep -q openshift_pool_id
            then
                echo "The OpenShift Pool ID is required."
                echo "Please run: 'qubinode-installer -p ocp3 -m rhsm' or modify"
                echo "${playbooks_dir}/vault/ocp3.yml 'openshift_pool_id'"
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
        echo "Please pass -p flag for ocp3/okd3."
        exit 1
      fi
    fi
}

function get_all_nodes () {
    printf "\n\n*********************\n"
    printf "* OpenShift Nodes *\n"
    printf "*********************\n\n"
    while read line
    do
        HOST=$(echo $line |awk -v pattern="$openshift_product" '$0~pattern{print $1}')
        IP=$(echo $line|awk -v pattern="$openshift_product" '$0~pattern{print $2}'|cut -d'=' -f2)
        if [ "A${IP}" != "A" ]
        then
           echo "$IP $HOST.${domain}"
       fi
    done < $inventory_file
}

function qubinode_deploy_openshift () {
    # Load function variables
    setup_variables
    openshift3_variables

    # Check if the cluster is reponding
    WEBCONSOLE_STATUS=$(check_webconsole_status)

    # skips these steps if OCP cluster is responding
    if [[ $WEBCONSOLE_STATUS -ne 200 ]]
    then
        # Load functions
        qubinode_rhsm_register  # ensure system is registered
        validate_openshift_pool_id # ensure it's attached to the ocp pool
    fi

    if [ ! -f "${openshift_deployment_size_yml}" ]
    then
        echo "Running check_openshift3_size_yml"
        check_openshift3_size_yml
    fi

    # Check for openshift user
    if grep '""' "${ocp3_vars_file}"|grep -q openshift_user
    then
        echo "Setting openshift_user variable to $CURRENT_USER in ${ocp3_vars_file}"
        sed -i "s#openshift_user:.*#openshift_user: "$CURRENT_USER"#g" "${ocp3_vars_file}"
        if grep '""' "${ocp3_vars_file}"|grep -q openshift_user
        then
            echo "Could not determine the openshift_user variable, please resolve and try again"
            exit 1
        fi
    fi

    # skips these steps if OCP cluster is responding
    if [[ $WEBCONSOLE_STATUS -ne 200 ]]
    then
        # ensure KVMHOST is setup as a jumpbox
        run_cmd="ansible-playbook ${openshift3_setup_deployer_node_playbook}"
        $run_cmd || exit_status "$run_cmd" $LINENO
        if [ ! -d "${openshift_ansible_dir}" ]
        then
            echo "Could not find ${openshift_ansible_dir}"
            echo "Ensure the openshift installer is installed and try again."
            exit 1
        fi
     fi

    # Generate the openshift inventory
    run_cmd="ansible-playbook ${openshift3_inventory_generator_playbook}"
    $run_cmd || exit_status "$run_cmd" $LINENO
    # Set the OpenShift inventory file
    INVENTORYFILE=$(find "${hosts_inventory_dir}" -name inventory.3.11.rhel* -print)
    if [ "A${INVENTORYFILE}" != "A" ]
    then
        HTPASSFILE=$(cat $INVENTORYFILE | grep openshift_master_htpasswd_file= | awk '{print $2}')
    else
        echo "Could not find the openshift inventory file inventory.3.11.rhel under ${hosts_inventory_dir}"
        exit 1
    fi

    # Ensure the inventory file exists
    if [ ! -f "${INVENTORYFILE}" ]
    then
        echo "Installation aborted: cannot find the inventory file ${INVENTORYFILE}"
        exit
    fi

    # skips these steps if OCP cluster is responding
    if [[ $WEBCONSOLE_STATUS -ne 200 ]]
    then
        # run openshift pre deployment checks
        echo "Running Qubi node openshift deployment checks."
        run_cmd="ansible-playbook -i ${INVENTORYFILE} ${openshift3_pre_deployment_checks_playbook}"
        $run_cmd || exit_status "$run_cmd" $LINENO
    fi

    # ensure htpassword file is created and populated
    ensure_ocp3_basic_auth_file

    # run openshift installation
    if [[ ${product_in_use} == "ocp3" ]]
    then
        if [[ ! -d ${openshift_ansible_dir} ]]; then
          ansible-playbook ${openshift3_setup_deployer_node_playbook}
        fi

        cd "${openshift_ansible_dir}"
        run_cmd="ansible-playbook -i $INVENTORYFILE playbooks/prerequisites.yml"
        echo "Running OpenShift prerequisites"
        $run_cmd || exit_status "$run_cmd" $LINENO
        echo "Running OpenShift prerequisites"
        printf "\n\n************************************************\n"
        printf     "* OpenShift prerequisites playbook run completed *\n"
        printf     "************************************************\n\n"

        echo "Deploying OpenShift Cluster"
        run_cmd="ansible-playbook -i $INVENTORYFILE playbooks/deploy_cluster.yml"
        $run_cmd || exit_status "$run_cmd" $LINENO

        openshift3_installation_msg
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
       for file in $(echo ${ocp3_ocp3_vars_files})
        do
            test -f $file && rm -f $file
        done
    fi

    # Remove okd3 yml files
    if [ "A${product}" == "Aokd3" ]
    then
        for file in $(echo ${okd3_ocp3_vars_files})
        do
            test -f $file && rm -f $file
        done
    fi
    printf "\n\n************************************************\n"
    printf     "* OpenShift Cluster and Nodes are deleted *\n"
    printf     "************************************************\n\n"
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
        echo "Running teardown"
        ansible-playbook "${NODES_PLAY}" --extra-vars "vm_teardown=true" || exit $?
        qubinode_teardown_cleanup
        #if sudo virsh list | grep -q "'${master}\|${node}\|${infra}'"
        #then
        #    echo "Running teardown"
        #    ansible-playbook "${NODES_PLAY}" --extra-vars "vm_teardown=true" || exit $?
        #    qubinode_teardown_cleanup
        #elif ! sudo virsh list | grep -q "'${master}\|${node}\|${infra}'"
        #then
        #    qubinode_teardown_cleanup
        #else
        #    qubinode_teardown_cleanup
        #fi
    else
        echo "No changes will be made"
        exit
    fi
}


function qubinode_autoinstall_openshift () {
    product_in_use="ocp3" # Tell the installer this is openshift3 installation
    openshift_auto_install=true # Tells the installer to use defaults options
    update_variable=true

    # Check current deployment size
    current_deployment_size=$(awk '/openshift_deployment_size:/ {print $2}' "${ocp3_vars_file}")

    # The default openshift size is stanadard
    # This ensures that if the size is already set
    # it does not get overwritten
    if [ "A${current_deployment_size}" == 'A""' ]
    then
        echo "Setting Openshift deployment size to standard."
        sed -i "s/openshift_deployment_size:.*/openshift_deployment_size: standard/g" "${ocp3_vars_file}"
    else
        echo "OpenShift 3 deployment size is $current_deployment_size"
    fi

    printf "\n\n***************************\n"
    printf "* Running qubinode perquisites *\n"
    printf "******************************\n\n"
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
    sed -i "s/openshift_auto_install:.*/openshift_auto_install: "$openshift_auto_install"/g" "${ocp3_vars_file}"
    openshift_enterprise_deployment
    openshift3_installation_msg
}

function ping_nodes () {
    echo "Running ping_nodes"
    openshift3_variables
    HOSTS=$(awk -v pattern="$openshift_product" '$0~pattern{print $1}' "${inventory_file}")
    TEMP_INVENTORY=$(mktemp)
    PING_RESULTS=$(mktemp)
    echo "[all]" > $TEMP_INVENTORY
    for host in $(echo $HOSTS)
    do
        echo "${host}.${domain}" >> $TEMP_INVENTORY
        ansible ${host}.${domain} -i $TEMP_INVENTORY -m ping 2>&1 | tee -a $PING_RESULTS >/dev/null
    done
    # Exit if total available host does not match what is expected
   PINGED_NODES_TOTAL=$(awk '/ok=1/ {print $1}' "${PING_RESULTS}"|wc -l)
   PINGED_NODES=$(awk '/ok=1/ {print $1}' "${PING_RESULTS}")
   PINGED_FAILED_NODES=$(awk '/ok=0/ {print $1}' "${PING_RESULTS}")
   PINGED_MASTER=$(echo "${PINGED_NODES}" |grep master|wc -l)

   if [ "A${openshift_deployment_size}" == "Aminimal" ]
   then
       TOTAL_NODES=3
       MASTERS=1
   elif [ "A${openshift_deployment_size}" == "Asmall" ]
   then
       TOTAL_NODES=5
       MASTERS=1
    elif [ "A${openshift_deployment_size}" == "Astandard" ]
    then
        TOTAL_NODES=5
        MASTERS=1
    elif [ "A${openshift_deployment_size}" == "Aperformance" ]
    then
        TOTAL_NODES=8
        MASTERS=3
    else
        echo "The OpenShift deployment size of **${openshift_deployment_size}** is unknown"
        echo "Installation aborted"
        exit 1
    fi
}


function are_openshift_nodes_available () {
    echo "Running are_openshift_nodes_available"

    # Check for connectivity to nodes and retun TOTAL_NODES
    # and PINGED_NODES_TOTAL variables.
    ping_nodes

    # Check if the right number of nodes are deployed
    # and master nodes are deployed and return DEPLOY_OPENSHIFT_NODES
    if [ "A${PINGED_NODES_TOTAL}" != "A${TOTAL_NODES}" ]
    then
        printf "\n\n The ocp3 installation profile of ${openshift_deployment_size} requires\
                \n a total of ${TOTAL_NODES} nodes, found $PINGED_NODES_TOTAL nodes.\n\n"

        DEPLOY_OPENSHIFT_NODES=1
    elif [ "A${PINGED_MASTER}" != "A${MASTERS}" ]
    then
        DEPLOY_OPENSHIFT_NODES=1
     else
        DEPLOY_OPENSHIFT_NODES=0
     fi

    if [ "A${DEPLOY_OPENSHIFT_NODES}" != "A1" ]
    then
        printf "\n\n Found all ${TOTAL_NODES} nodes required for the Cluster profile size ${openshift_deployment_size}.\n\n"

        # Create a report of all nodes including their IP address and FQDN
        divider===============================
        divider=$divider$divider
        header="\n %-035s %010s\n"
        format=" %-035s %010s\n"
        width=50
        printf "$header" "OCP3 Cluster Nodes" "IP Address" >"${project_dir}/openshift_nodes"
        printf "%$width.${width}s\n" "$divider" >>"${project_dir}/openshift_nodes"
        for host in $(echo "${PINGED_NODES}")
        do
            IP=$(host "${host}" | awk '{print $4}')
            cleanStaleKnownHost "${ADMIN_USER}" "${host}" "${IP}"
            printf "$format" "${host}"  "${IP}" >> "${project_dir}/openshift_nodes"
        done

    fi
}

function deploy_openshift3_nodes () {
    # Deploys nodes for openshift 3
    ask_user_which_openshift_product
    qubinode_openshift_nodes
    validate_opeshift3_nodes_deployment
}

function validate_opeshift3_nodes_deployment () {
    # Validate OpenShift nodes deployment
    # check connectivity to nodes and return
    # DEPLOY_OPENSHIFT_NODES variable
    are_openshift_nodes_available

    # exit when nodes fail to deploy
    if [ "A${DEPLOY_OPENSHIFT_NODES}" == "A1" ]
    then

        msg="\n A ${openshift_deployment_size} cluster requires ${TOTAL_NODES} nodes. \
             \n A total of ${PINGED_NODES_TOTAL} nodes were deployed."

        if [ "A${PINGED_NODES_TOTAL}" != "A${TOTAL_NODES}" ]
        then
           printf "$msg"
           printf "\n Failed nodes are: \n"
           printf " ${PINGED_FAILED_NODES}\n"
           printf "\n Please troubleshoot why nodes aren't being deployed."
           printf "\n Try removing all nodes with the below command and try again."
           printf "\n\n ./qubinode-installer -p ocp3 -d \n\n"
           exit 1
        fi
    fi
}

function generate_htpasswd_file () {
    get_admin_user_password
    run_cmd="htpasswd -c -b ${HTPASSFILE} $OCUSER $admin_user_passowrd"
    echo "Generating encrypted hash for ocp3 basic auth"
    $run_cmd
}

function ensure_ocp3_basic_auth_file () {
    # ensure htpassword file is created and populated
    if [[ ! -f ${HTPASSFILE} ]]
    then
        echo "Creating OpenShift htpasswd file ${HTPASSFILE}"
        generate_htpasswd_file
    fi

    if ! grep $OCUSER ${HTPASSFILE} >/dev/null 2>&1
    then
        echo "Creating OpenShift htpasswd file ${HTPASSFILE}"
        rm -f ${HTPASSFILE}
        generate_htpasswd_file
    fi
}

function ensure_ocp_default_user () {
    # Get password from ansible vault
    get_admin_user_password

    oc login ${web_console} --username="${OCUSER}" --password="${admin_user_passowrd}" --insecure-skip-tls-verify=true
    if [ $? -eq 1 ]
    then
       echo "Log to $web_console failed as user $ocp_user"
       echo "Setting basic for ocp3"
       ensure_ocp3_basic_auth_file
       ansible-playbook -i inventory/inventory.3.11.rhel.gluster /usr/share/ansible/openshift-ansible/playbooks/openshift-master/config.yml
    fi
}

function openshift_enterprise_deployment () {
    echo "Running openshift_enterprise_deployment"
    # This function is called by the menu option -p ocp3
    # It's the primary function that starts the deployment
    # of the OCP3 cluster.

    # Set global product variable to OpenShift 3
    # This variable needs to be set before all else
    openshift_product=ocp3
    sed -i "s/openshift_product:.*/openshift_product: "$openshift_product"/g" "${ocp3_vars_file}"
    sed -i "s/openshift_deployment_type:.*/openshift_deployment_type: openshift-enterprise/g" "${ocp3_vars_file}"

    # Load all global openshift variable
    set_openshift_production_variables

    # Check if OpenShift nodes are deployed
    # and return the variable DEPLOY_OPENSHIFT_NODES
    are_openshift_nodes_available

    # Deploy OpenShift Nodes if they are not deployed
    if [ "A${DEPLOY_OPENSHIFT_NODES}" == "A1" ]
    then
        deploy_openshift3_nodes
    fi

    # Check if the OCP3 cluster is already deployed
    check_webconsole_status

    if [[ $WEBCONSOLE_STATUS -ne 200 ]]
    then
        ask_user_which_openshift_product
        are_openshift_nodes_available
        qubinode_deploy_openshift

        # Wait for OpenShift Console to come up
        sleep 45s

        # Ensure the qubinode user is added to openshift
        ensure_ocp_default_user

        # Report on OpenShift Installation
        openshift3_installation_msg
    else
        # Ensure the qubinode user is added to openshift
        ensure_ocp_default_user

        # Report on OpenShift Installation
        openshift3_installation_msg
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

   # Run post configuration tasks on Openshift Nodes
   if [ "A${STATUS}" != "A200" ]; then
       qubinode_openshift3_nodes_postdeployment
   fi
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
           get_admin_user_password
           bash "${project_dir}/lib/openshift-smoke-test.sh" "${web_console}" "${OCUSER}" "${admin_user_passowrd}"
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

function check_webconsole_status () {
    #echo "Running check_webconsole_status"
    # This function checks to see if the openshift console up
    # It expects a return code of 200

    #echo "Checking to see if Openshift is online."
    WEBCONSOLE_STATUS=$(curl --write-out %{http_code} --silent --output /dev/null "${web_console}" --insecure)
    return $WEBCONSOLE_STATUS
}

function openshift3_installation_msg () {
   # check connectivity to webconsole
   check_webconsole_status

   # Setup variables for smoketest
   get_admin_user_password
   SMOKETEST="${project_dir}/lib/openshift-smoke-test.sh"

   if [[ $WEBCONSOLE_STATUS -eq 200 ]]
   then
       # Run smoketest to ensure cluster is up
       echo "Running post installation test"
       bash "${SMOKETEST}" "${web_console}" "${OCUSER}" "${admin_user_passowrd}"

       MASTER_NODE=$(cat "${project_dir}/inventory/hosts" | grep "master01" | awk '{print $1}')
       IDM_IP=$(cat "${idm_vars_file}" | grep "idm_server_ip:" | awk '{print $2}')
       printf "\n\n*******************************************************\n"
       printf "\nDeployment steps for ${product} cluster is complete.\n"
       printf "\nCluster login: ${web_console}\n"
       printf "     Username: ${OCUSER}\n"
       printf "     Password: <yourpassword>\n\n"
       cat "${project_dir}/openshift_nodes"
       printf "\n\nIDM DNS Server login: https://${prefix}-dns01.${domain}\n"
       printf "     Username: admin\n"
       printf "     Password: <yourpassword>\n"
       printf "IdM server IP: $IDM_IP\n\n"
       if [ "A${APP_STATUS}" == "A200" ]
       then
           printf " WARNING: Although the cluster appears to be up, the smoketest was not successfull.\n\n"
           printf " Please check the health of your cluster.\n\n"
       fi
       printf "*******************************************************\n"
   else
       echo  "FAILED to connect to Openshift Console URL:  ${web_console}"
       printf "\n\n*********************\n"
       exit 1
   fi
}
