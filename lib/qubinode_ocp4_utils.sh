#!/bin/bash

function openshift4_variables () {
    playbooks_dir="${project_dir}/playbooks"
    ocp4_pull_secret="${project_dir}/pull-secret.txt"
    cluster_name=$(awk '/^cluster_name/ {print $2; exit}' "${ocp4_vars_file}")
    ocp4_cluster_domain=$(awk '/^ocp4_cluster_domain/ {print $2; exit}' "${ocp4_vars_file}")
    lb_name_prefix=$(awk '/^lb_name_prefix/ {print $2; exit}' "${ocp4_vars_file}")
    podman_webserver=$(awk '/^podman_webserver/ {print $2; exit}' "${ocp4_vars_file}")
    lb_name="${lb_name_prefix}-${cluster_name}"
    ocp4_pull_secret="${project_dir}/pull-secret.txt"

    # load kvmhost variables
    kvm_host_variables
}

function check_for_pull_secret () {
    ocp4_pull_secret="${project_dir}/pull-secret.txt"
    if [ ! -f "${ocp4_pull_secret}" ]
    then
        printf "%s\n\n\n" ""
        printf "%s\n\n\n" "${yel}    Your OpenShift Platform pull secret is missing!${end}"
        printf "%s\n" "  Please download your pull-secret from: "
        printf "%s\n" "  https://cloud.redhat.com/openshift/install/metal/user-provisioned"
        printf "%s\n\n" "  and save it as ${ocp4_pull_secret}"
        exit
    fi
}

function openshift4_standard_desc() {
cat << EOF
    ${yel}=========================${end}
    ${mag}Deployment Type: Standard${end}
    ${yel}=========================${end}
     3 masters w/16G and 4 vcpu
     3 workers w/16G and 4 vcpu

    ${cyn}========${end}
    Features
    ${cyn}========${end}
     - nfs-provisioner for image registry
EOF
}

function openshift4_minimal_desc() {
cat << EOF
    ${yel}=========================${end}
    ${mag}Deployment Type: Minimal${end}
    ${yel}=========================${end}
     3 masters w/8G memory and 2 vcpu
     0 workers

    ${cyn}========${end}
    Features
    ${cyn}========${end}
     - nfs-provisioner for image registry
EOF
}

function openshift4_prechecks () {
    ocp4_vars_file="${project_dir}/playbooks/vars/ocp4.yml"
    ocp4_sample_vars="${project_dir}/samples/ocp4.yml"
    all_vars_file="${project_dir}/playbooks/vars/all.yml"
    if [ ! -f "${ocp4_vars_file}" ]
    then
        cp "${ocp4_sample_vars}" "${ocp4_vars_file}"
    fi

    openshift4_variables
    collect_system_information
    check_for_required_role openshift-4-loadbalancer
    check_for_required_role swygue.coreos-virt-install-iso

    # Check for OCP4 pull sceret
    check_for_pull_secret
    openshift4_kvm_health_check
    if [[ ${KVM_IN_GOOD_HEALTH} == "ready" ]]; then
      # Ensure firewall rules
      if ! sudo firewall-cmd --list-ports | grep -q '32700/tcp'
      then
          echo "Setting firewall rules"
          sudo firewall-cmd --add-port={8080/tcp,80/tcp,443/tcp,6443/tcp,22623/tcp,32700/tcp} --permanent
          sudo firewall-cmd --reload
      fi

    fi

    # Get the lastest OCP4 version
    curl -sOL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/release.txt
    current_version=$(cat release.txt | grep Name:  |  awk '{print $2}')
    sed -i "s/^ocp4_release:.*/ocp4_release: ${current_version}/"   "${project_dir}/playbooks/vars/ocp4.yml"

    # Ensure Openshift Subscription Pool is attached
    check_for_openshift_subscription
    #get_subscription_pool_id 'Red Hat OpenShift Container Platform'
}


function remove_ocp4_vms () {
    #clean up
    all_vms=(bootstrap)
    deleted_vms=()

    masters=$(sudo virsh list  --all | grep master | awk '{print $2}')
    for vm in $masters
    do
        all_vms+=( "$vm" )
    done

    compute=$(sudo virsh list  --all | grep compute | awk '{print $2}')
    for vm in $compute
    do
        all_vms+=( "$vm" )
    done

    #build_ocp4_vm_list

    for vm in "${all_vms[@]}"
    do
        if sudo virsh list --all | grep -q $vm
        then
            state=$(sudo virsh list --all | grep $vm|awk '{print $3}')
            if [ "A${state}" == "Arunning" ]
            then
                isvmRunning | while read VM
                do
                    sudo virsh shutdown $vm
                    sleep 3
                done
                sudo virsh destroy $vm
                sudo virsh undefine $vm --remove-all-storage
                if ! sudo virsh list --all | grep -q $vm
                then
                    printf "%s\n" " $vm has was powered off and removed"
                    deleted_vms+=( "$vm" )
                    all_vms=("${all_vms[@]/$vm/}")
                fi
            elif [ "A${state}" == "Ashut" ]
            then
                sudo virsh undefine $vm --remove-all-storage
                if ! sudo virsh list --all | grep -q $vm
                then
                    printf "%s\n" " $vm was already powered, it has been removed"
                    deleted_vms+=( "$vm" )
                    all_vms=("${all_vms[@]/$vm/}")
                fi
            else
                sudo virsh destroy $vm
                sudo virsh undefine $vm --remove-all-storage
                if ! sudo virsh list --all | grep -q $vm
                then
                    printf "%s\n" " $vm state was ${state}, it has been removed"
                    deleted_vms+=( "$vm" )
                    all_vms=("${all_vms[@]/$vm/}")
                fi
            fi
        else
            printf "%s\n" " $vm has been removed"
            deleted_vms+=( "$vm" )
            all_vms=("${all_vms[@]/$vm/}")
        fi
    done

    if [ "${#all_vms[@]}" -ne "${#deleted_vms[@]}" ]
    then
        printf "%s\n" " There is a total of ${#all_vms[@]}, ${#deleted_vms[@]} were deleted."
        printf "%s\n" " The following VMs could not be deleted. Please manually delete them and try again."
        for i in "${all_vms[@]}"
        do
            printf "%s\n" "    ${i:-other}"|grep -v other
        done
        exit 0
    fi
}

function state_check(){
cat << EOF
    ${yel}**************************************** ${end}
    ${mag}Checking Machine for stale openshift vms ${end}
    ${yel}**************************************** ${end}
EOF
    clean_up_stale_vms dns
    clean_up_stale_vms bootstrap
    clean_up_stale_vms master
    clean_up_stale_vms compute
}

function clean_up_stale_vms(){
    KILLVM=true
    stalemachines=$(sudo virsh list  --all | grep $1 | awk '{print $2}')
    for vm in $stalemachines
    do
       KILLVM=false
    done

    if [[ $KILLVM == "true" ]]; then 
        stale_vms=$(sudo ls "${libvirt_dir}/" | grep $1)
        if [[ ! -z $stale_vms ]]; then 
            for old_vm in $stale_vms
            do
            if [[ "$old_vm" == *${1}* ]]; then 
                sudo rm  -f "${libvirt_dir}/$old_vm"
            fi
            done 
        fi 
    fi

}

function configure_local_storage () {
    #TODO: you be presented with the choice between localstorage or ocs. Not both.
    printf "%s\n\n" ""
    read -p "     ${def}Enter the size you want in GB for local storage, default is 100: ${end} " vdb
    vdb_size="${vdb:-100}"
    compute_vdb_size=$(echo ${vdb_size}| grep -o '[[:digit:]]*')
    confirm "     ${def}You entered${end} ${yel}$compute_vdb_size${end}${def}, is this correct?${end} ${yel}yes/no${end}"
    if [ "A${response}" == "Ayes" ]
    then
        sed -i "s/compute_vdb_size:.*/compute_vdb_size: "$compute_vdb_size"/g" "${ocp4_vars_file}"
        printf "%s\n" ""
        printf "%s" "    ${def}Your compute_hd_size is now set to${end} ${yel}${compute_disk_size}G${end}"
    fi

cat << EOF
    ${yel}=========================${end}
    ${mag}Select volume Mode: ${end}
    ${yel}=========================${end}
    1) Filesystem - Presented to the OS as a file system export to be mounted.
    2) Block - Presented to the operating system (OS) as a block device.
EOF
    local choice
	read -p " ${cyn}Enter choice [ 1 - 2] ${end}" choice
	case $choice in
	    1) storage_type=filesystem
            ;;
            2) storage_type=block
            ;;
	    3) exit 0;;
	    *) printf "%s\n\n" " ${RED}Error...${STD}" && sleep 2
	esac
        confirm " Continue with  Volume Mode for $storage_type OpenShift deployment? yes/no"
        if [ "A${response}" == "Ayes" ]
        then
            set_local_volume_type
            exit 0
        else
            configure_local_storage
        fi
}

function set_local_volume_type () {
  if [[ $storage_type == "filesystem" ]]; then 
    sed -i "s/localstorage_filesystem:.*/localstorage_filesystem: true/g" "${ocp4_vars_file}"
    sed -i "s/localstorage_block:.*/localstorage_block: false/g" "${ocp4_vars_file}"
  elif [[ $storage_type == "block" ]]; then 
    sed -i "s/localstorage_filesystem:.*/localstorage_filesystem: false/g" "${ocp4_vars_file}"
    sed -i "s/localstorage_block:.*/localstorage_block: true/g" "${ocp4_vars_file}"
  fi 
}

function confirm_minimal_deployment () {
    all_vars_file="${project_dir}/playbooks/vars/all.yml"
    openshift4_minimal_desc
    #confirm " This Option will set your compute count to 2? yes/no"
    #if [ "A${response}" == "Ayes" ]
    #then
        compute_num=0
        master_vcpu=2
        master_memory_size=8
        sed -i "s/master_mem_size:.*/master_mem_size: "$master_memory_size"/g" "${ocp4_vars_file}"
        sed -i "s/compute_count:.*/compute_count: "$compute_num"/g" "${ocp4_vars_file}"
        sed -i "s/master_vcpu:.*/master_vcpu: "$master_vcpu_count"/g" "${ocp4_vars_file}"
        sed -i "s/ocp_cluster_size:.*/ocp_cluster_size: minimal/g" "${all_vars_file}"
        sed -i "s/memory_profile:.*/memory_profile: minimal/g" "${all_vars_file}"
        sed -i "s/storage_profile:.*/storage_profile: minimal/g" "${all_vars_file}"
    #fi
}


is_node_up () {
    IP=$1
    VMNAME=$2
    WAIT_TIME=0
    DNSIP=$(cat playbooks/vars/idm.yml  |grep idm_server_ip: | awk '{print $2}')
    until ping -c4 "${NODE_IP}" >& /dev/null || [ $WAIT_TIME -eq 60 ]
    do
        sleep $(( WAIT_TIME++ ))
    done
    ssh -q -o "StrictHostKeyChecking=no" core@${IP} 'hostname -s' &>/dev/null
    NAME_CHECK=$(ssh core@${IP} 'hostname -s')
    #NAME_CHECK=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" core@${IP} 'hostname -s')
    ETCD_CHECK=$(ssh core@${IP} 'dig @${DNSIP} -t srv _etcd-server-ssl._tcp.${cluster_name}.lunchnet.example|grep "^_etcd-server-ssl."|wc -l')
    echo ETCD_CHECK=$ETCD_CHECK
    if [ "A${VMNAME}" != "A${NAME_CHECK}" ]
    then
      hostnamectl set-hostname "${VMNAME}.${cluster_name}.${domain}"
    fi
    if [ "A${ETCD_CHECK}" != "A3" ]
    then
        echo "Could not determine if $VMNAME was properly deployed."
        exit 1
    else
        echo "$VMNAME was properly deployed"
    fi
}

function check_webconsole_status () {
    #echo "Running check_webconsole_status"
    # This function checks to see if the openshift console up
    # It expects a return code of 200

    # load required variables
    openshift4_variables
    #echo "Checking to see if Openshift is online."
    web_console="https://console-openshift-console.apps.${cluster_name}.${ocp4_cluster_domain}"
    WEBCONSOLE_STATUS=$(curl --write-out %{http_code} --silent --output /dev/null "${web_console}" --insecure)
    return $WEBCONSOLE_STATUS
}

function pingreturnstatus() {
  ping -q -c3 $1 > /dev/null

  if [ $? -eq 0 ]
  then
    true
    return 0
  else
    false
    return 1
  fi
  }


function ignite_node () {
    NODE_PLAYBOOK="playbooks/${1}"
    NODE_LIST="${project_dir}/rhcos-install/node-list"
    touch $NODE_LIST

    if ! grep -q "$VMNAME" "${NODE_LIST}"
    then
        echo "$VMNAME" >> "${project_dir}/rhcos-install/node-list"
    fi

    if grep -q "shut off" $DOMINFO
    then
        #TODO: add option to only start VM if the cluster has not been deployed
        echo "The $VMNAME node appears to be deploy but powered off"
        sudo virsh start $VMNAME
        is_node_up $NODE_IP $VMNAME
    elif grep -q "running" $DOMINFO
    then
        echo "The boostrap node appears to be running"
        is_node_up $NODE_IP $VMNAME
    else
        ansible-playbook "${NODE_PLAYBOOK}" -e vm_name=${VMNAME} -e vm_mac_address=${NODE_MAC} -e coreos_host_ip=${NODE_IP}
        echo "Wait for ignition"
        WAIT_TIME=0
        until ping -c4 "${NODE_IP}" >& /dev/null || [ $WAIT_TIME -eq 60 ]
        do
            sleep $(( WAIT_TIME++ ))
        done

        echo -n "Igniting $VMNAME node "
        while ping -c 1 -W 3 "${NODE_IP}" >& /dev/null
        do
            echo -n "."
            sleep 1
        done
        echo "done!"
        ssh-keygen -R "${NODE_IP}" >& /dev/null
        echo "Starting $VMNAME"
        sudo virsh start $VMNAME &> /dev/null
        is_node_up $NODE_IP $VMNAME
    fi
}


deploy_bootstrap_node () {
    # Deploy Bootstrap
    DOMINFO=$(mktemp)
    VMNAME=bootstrap
    sudo virsh dominfo $VMNAME > $DOMINFO 2>/dev/null
    #NODE_NETINFO=$(mktemp)
    #sudo virsh net-dumpxml ${cluster_name} | grep 'host mac' > $NODE_NETINFO
    BOOTSTRAP=$(sudo virsh net-dumpxml ${cluster_name} | grep  bootstrap | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
    COREOS_IP=$(sudo virsh net-dumpxml ${cluster_name} | grep  bootstrap  | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
    ansible-playbook playbooks/ocp4_07_deploy_bootstrap_vm.yml  -e vm_mac_address=${BOOTSTRAP} -e coreos_host_ip=${COREOS_IP}
    sleep 30s
}

deploy_master_nodes () {
    ## Deploy Master
    for i in {0..2}
    do
        MASTER=$(sudo virsh net-dumpxml ${cluster_name} | grep  master-${i} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
        COREOS_IP=$(sudo virsh net-dumpxml ${cluster_name} | grep  master-${i} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
        ansible-playbook playbooks/ocp4_07.1_deploy_master_vm.yml  -e vm_mac_address=${MASTER}   -e vm_name=master-${i} -e coreos_host_ip=${COREOS_IP}
        sleep 30s
    done

}

deploy_compute_nodes () {
    # Deploy computes
    for i in {0..1}
    do
      COMPUTE=$(sudo virsh net-dumpxml ${cluster_name} | grep  compute-${i} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
      COREOS_IP=$(sudo virsh net-dumpxml ${cluster_name} | grep   compute-${i} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
      ansible-playbook playbooks/ocp4_07.2_deploy_compute_vm.yml  -e vm_mac_address=${COMPUTE}   -e vm_name=compute-${i} -e coreos_host_ip=${COREOS_IP}
      sleep 10s
    done
}



wait_for_ocp4_nodes_shutdown () {
  i="$(sudo virsh list | grep running | grep master |wc -l)"

  while [ $i -ne 0 ]
  do
    echo "waiting master nodes to shutdown ${i}"
    sleep 10s
    i="$(sudo virsh list | grep running | grep master  |wc -l)"
  done

  w="$(sudo virsh list | grep running | grep compute |wc -l)"

  while [ $w -ne 0 ]
  do
    echo "waiting compute nodes to shutdown ${w}"
    sleep 10s
    w="$(sudo virsh list | grep running | grep compute  |wc -l)"
  done

}

start_ocp4_deployment () {
    ansible-playbook playbooks/ocp4_08_startup_coreos_nodes.yml
    ignition_dir="${project_dir}/ocp4"
    install_cmd=$(mktemp)
    cd "${project_dir}"
    echo "openshift-install --dir=${ignition_dir} wait-for bootstrap-complete --log-level debug" > $install_cmd
    bash $install_cmd
}

function empty_directory_msg () {
  cat << EOF
  # oc get pod -n openshift-image-registry
  # oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'
  # oc get pod -n openshift-image-registry
  # oc get clusteroperators
EOF
}

openshift4_kvm_health_check () {
    KVM_IN_GOOD_HEALTH=""
    requested_nat=$(cat ${vars_file}|grep  cluster_name: | awk '{print $2}' | sed 's/"//g')
    check_image_path=$(cat ${vars_file}| grep kvm_host_libvirt_dir: | awk '{print $2}')
    libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/playbooks/vars/kvm_host.yml")
    os_qcow_image_name=$(awk '/^os_qcow_image_name/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
    create_lvm=$(awk '/create_lvm:/ {print $2;exit}' "${project_dir}/playbooks/vars/kvm_host.yml")
  
    if ! sudo virsh net-list | grep -q $requested_brigde; then
      KVM_STATUS="not ready"
    fi
  
    #if ! sudo virsh net-list | grep -q $requested_nat; then
    #  KVM_IN_GOOD_HEALTH="not ready"
    #fi
  
    # If dedicated disk for libvirt images, check for the volume group
    if [ "A${create_lvm}" == "Ayes" ]
    then
        if ! sudo vgdisplay | grep -q $vg_name
        then
            KVM_STATUS="not ready"
        fi
    fi
  
    if [ ! -d $check_image_path ]
    then
        KVM_STATUS="not ready"
    fi
  
    if sudo bash -c '[[ ! -f '${libvirt_dir}'/'${os_qcow_image_name}' ]]'
    then
        KVM_STATUS="not ready"
    fi
  
    if ! [ -x "$(command -v virsh)" ]
    then
        KVM_STATUS="not ready"
    fi
  
    if ! [ -x "$(command -v firewall-cmd)" ]
    then
        KVM_STATUS="not ready"
    fi
  
    if [ "A$KVM_STATUS" != "Anot ready" ]
    then
        KVM_IN_GOOD_HEALTH=ready
    fi
}

openshift4_idm_health_check () {
    IDM_IN_GOOD_HEALTH=ready
    
    if [[ ! -f $idm_vars_file ]]; then
      IDM_IN_GOOD_HEALTH="not ready"
    fi
    
    idm_ipaddress=$(cat ${idm_vars_file} | grep idm_server_ip: | awk '{print $2}')
    if ! pingreturnstatus ${idm_ipaddress}; then
      IDM_IN_GOOD_HEALTH="not ready"
    fi
    
    dns_query=$(dig +short @${idm_ipaddress} qbn-dns01.${domain})
    if echo $dns_query | grep -q 'no servers could be reached'
    then
          IDM_IN_GOOD_HEALTH="not ready"
    fi
}


function ping_openshift4_nodes () {
#TODO: validate if this funciton is still need
    IS_OPENSHIFT4_NODES="not ready"
    masters=$(cat $ocp4_vars_file | grep master_count:| awk '{print $2}')
  
    if [ "A${masters}" != "A" ]
    then
        for i in $(seq $masters)
        do
            vm="master-$((i-1))"
            if  pingreturnstatus ${vm}.${cluster_name}.${domain} > /dev/null 2>&1; then
              echo "${vm}.${cluster_name}.lab.example is online"
              IS_OPENSHIFT4_NODES=ready
            else
              echo "${vm}.${cluster_name}.lab.example is offline"
              IS_OPENSHIFT4_NODES="not ready"
              break
            fi
        done
    else
        IS_OPENSHIFT4_NODES="not ready"
    fi

    compute=$(cat $ocp4_vars_file | grep compute_count:| awk '{print $2}')
    if [ "A${compute}" != "A" ]
    then
        for i in $(seq $compute)
        do
            vm="compute-$((i-1))"
            if  pingreturnstatus ${vm}.${cluster_name}.${domain} > /dev/null 2>&1; then
              echo "${vm}.${cluster_name}.lab.example is online"
              IS_OPENSHIFT4_NODES=ready
            else
              echo "${vm}.${cluster_name}.lab.example is offline"
              IS_OPENSHIFT4_NODES="not ready"
              break
            fi
        done
    else
        IS_OPENSHIFT4_NODES="not ready"
    fi

    #printf "%s\n\n" "  The OCP4 nodes health status is $IS_OPENSHIFT4_NODES."

}

function check_openshift4_size_yml () {
    check_hardware_resources
    storage_profile=$(awk '/^storage_profile:/ {print $2}' "${vars_file}")
    memory_profile=$(awk '/^memory_profile:/ {print $2}' "${vars_file}")
    ocp_cluster_size=$(awk '/^ocp_cluster_size:/ {print $2}' "${vars_file}")

    #if [[ "A${memory_profile}" == "Anotmet" ]] || [[ "A${storage_profile}" == "Anotmet" ]]
    if [ "A${ASK_SIZE}" == "Atrue" ]
    then
        memory_size="${memory_profile}"
        bash ${project_dir}/lib/qubinode_openshift_sizing_menu.sh $memory_size
    elif [[ "A${ocp_cluster_size}" == "Anotmet" ]] || [[ "A${ocp_cluster_size}" == "Aminimal" ]]
    then
        printf "%s\n" " Your hardware does not meet our recommended sizing."
        printf "%s\n" " Your disk size is $DISK_SIZE_HUMAN and your total memory is $TOTAL_MEMORY."
        printf "%s\n" " You can continue with a minimum OpenShift 3 cluster. There are no gurantees"
        printf "%s\n\n" " the installation will be successful or if deployed your cluster may be very slow."

        printf "%s\n\n" " To choose a minimal install and other customization options."
        printf "%s\n\n" " Run: ./qubinode-installer -p ocp4"
        exit 1
    fi
}

openshift4_enterprise_deployment () {
    # Ensure all preqs before continuing
    openshift4_prechecks

    # Setup the host system
    ansible-playbook playbooks/ocp4_01_deployer_node_setup.yml || exit 1

    # populate IdM with the dns entries required for OCP4
    ansible-playbook playbooks/ocp4_02_configure_dns_entries.yml  || exit 1

    # deploy the load balancer container
    ansible-playbook playbooks/ocp4_03_configure_lb.yml  || exit 1

    lb_container_status=$(sudo podman inspect -f '{{.State.Running}}' $lb_name 2>/dev/null)
    if [ "A${lb_container_status}" != "Atrue" ]
    then
        printf "%s\n" " The load balancer container ${cyn}$lb_name${end} did not deploy."
        printf "%s\n" " This step is done by running: ${grn}run ansible-playbook playbooks/ocp4_03_configure_lb.yml${end}"
        printf "%s\n" " Please investigate and try the intall again!"
        exit 1
    fi

    # Download the openshift 4 installer
    #TODO: this playbook should be renamed to reflect what it actually does
    ansible-playbook playbooks/ocp4_04_download_openshift_artifacts.yml  || exit 1

    # Create ignition files
    #TODO: check if the ignition files have been created longer than 24hrs
    # regenerate if they have been
    ansible-playbook playbooks/ocp4_05_create_ignition_configs.yml || exit 1

    # runs the role playbooks/roles/swygue.coreos-virt-install-iso
    # - downloads the cores os qcow images
    # - deploy httpd podman container
    # - serve up the ignition files and cores qcow image over the web server
    # TODO: make this idempotent, skips if the end state is already met
    # /opt/qubinode_webserver/4.2/images/
    ansible-playbook playbooks/ocp4_06_deploy_webserver.yml  || exit 1
    httpd_container_status=$(sudo podman inspect -f '{{.State.Running}}' $podman_webserver 2>/dev/null)
    if [ "A${httpd_container_status}" != "Atrue" ]
    then
        printf "%s\n" " The httpd container ${cyn}$podman_webserver${end} did not deploy."
        printf "%s\n" " This step is done by running: ${grn}run ansible-playbook playbooks/ocp4_06_deploy_webserver.yml${end}"
        printf "%s\n" " Please investigate and try the intall again!"
        exit 1
    fi

    # Get network information for ocp4 vms
    NODE_NETINFO=$(mktemp)
    sudo virsh net-dumpxml ${cluster_name} | grep 'host mac' > $NODE_NETINFO

    # Deploy the coreos nodes required
    #TODO: playbook should not attempt to start VM's if they are already running
    deploy_bootstrap_node
    deploy_master_nodes
    deploy_compute_nodes

    # Ensure first boot is complete
    # first boot is the initial deployment of the VMs
    # followed by a shutdown
    wait_for_ocp4_nodes_shutdown

    # Boot up the VM's starting the bootstrap node, followed by master, compute
    # Then start the ignition process
    start_ocp4_deployment

    # Show user post deployment steps to follow
    post_deployment_steps
}

reset_cluster_resources_default () {
    default_master_count=$(awk '/^master_count:/ {print $2; exit}' "${project_dir}/samples/ocp4.yml")
    default_master_hd_size=$(awk '/^master_hd_size:/ {print $2; exit}' "${project_dir}/samples/ocp4.yml")
    default_master_mem_size=$(awk '/^master_mem_size:/ {print $2; exit}' "${project_dir}/samples/ocp4.yml")
    default_master_vcpu=$(awk '/^master_vcpu:/ {print $2; exit}' "${project_dir}/samples/ocp4.yml")
    default_compute_count=$(awk '/^compute_count:/ {print $2; exit}' "${project_dir}/samples/ocp4.yml")
    default_compute_hd_size=$(awk '/^compute_hd_size:/ {print $2; exit}' "${project_dir}/samples/ocp4.yml")
    default_compute_mem_size=$(awk '/^compute_mem_size:/ {print $2; exit}' "${project_dir}/samples/ocp4.yml")
    default_compute_vcpu=$(awk '/^compute_vcpu:/ {print $2; exit}' "${project_dir}/samples/ocp4.yml")
    default_compute_local_storage=$(awk '/^compute_local_storage:/ {print $2; exit}' "${project_dir}/samples/ocp4.yml")

    sed -i "s/master_vcpu:.*/master_vcpu: "$default_master_vcpu"/g" "${ocp4_vars_file}"
    sed -i "s/master_mem_size:.*/master_mem_size: "$default_master_mem_size"/g" "${ocp4_vars_file}"
    sed -i "s/master_hd_size:.*/master_hd_size: "$default_master_hd_size"/g" "${ocp4_vars_file}"
    sed -i "s/master_count:.*/master_count: "$default_master_count"/g" "${ocp4_vars_file}"

    sed -i "s/compute_vcpu:.*/compute_vcpu: "$default_compute_count"/g" "${ocp4_vars_file}"
    sed -i "s/compute_mem_size:.*/compute_mem_size: "$default_compute_mem_size"/g" "${ocp4_vars_file}"
    sed -i "s/compute_hd_size:.*/compute_hd_size: "$default_compute_hd_size"/g" "${ocp4_vars_file}"
    sed -i "s/compute_count:.*/compute_count: "$default_compute_count"/g" "${ocp4_vars_file}"
}

function update_node_count () {
    #------------------------------------------
    # Update Node Count
    #------------------------------------------

    NODE=$1
    DEFAULT_VALUE=$2
    RC=0
    
    printf "%s\n\n" ""
    read -p "     ${def}Enter the number of ${NODE} nodes you would like: ${end} " user_input
    node_num="${user_input:-$DEFAULT_VALUE}"
    confirm "     ${def}You entered${end} ${yel}$node_num${end}${def}, is this correct?${end} ${yel}yes/no${end}"
    if [ "A${response}" == "Ayes" ]
    then
        printf "%s\n" ""
        if [ "A${NODE}" == "Amaster" ]
        then
            sed -i "s/master_count:.*/master_count: "$node_num"/g" "${ocp4_vars_file}"
        elif [ "A${NODE}" == "Acompute" ]
        then
            sed -i "s/compute_count:.*/compute_count: "$node_num"/g" "${ocp4_vars_file}"
        else
            printf "%s" "     ${red}Unknown node type $NODE!{end}"
            RC=1
        fi
        
        printf "%s\n\n" "     ${def}Your $NODE count is now set to${end} ${yel}$node_num${end}"
    fi
    return $RC
}

function update_node_disk_size () {
    #------------------------------------------
    # $NODE disk size
    #------------------------------------------

    NODE=$1
    DEFAULT_VALUE=$2
    RC=0

    printf "%s\n\n" ""
    read -p "     ${def}Enter the disk size in GB for the $NODE nodes, e.g. 120: ${end} " user_input
    hd_size="${user_input:-$DEFAULT_VALUE}"
    node_disk_size=$(echo ${hd_size}| grep -o '[[:digit:]]*')
    confirm "     ${def}You entered${end} ${yel}$node_disk_size${end}${def}, is this correct?${end} ${yel}yes/no${end}"
    if [ "A${response}" == "Ayes" ]
    then
        printf "%s\n" ""
        if [ "A${NODE}" == "Amaster" ]
        then
            sed -i "s/master_hd_size:.*/master_hd_size: "$node_disk_size"/g" "${ocp4_vars_file}"
        elif [ "A${NODE}" == "Acompute" ]
        then
            sed -i "s/compute_hd_size:.*/compute_hd_size: "$node_disk_size"/g" "${ocp4_vars_file}"
        else
            printf "%s" "     ${red}Unknown node type $NODE!{end}"
            RC=1
        fi
        printf "%s\n\n" "     ${def}Your $NODE disk size is now set to${end} ${yel}${node_disk_size}G${end}"
    fi
    return $RC
}

function update_node_mem_size () {
    #------------------------------------------
    # $NODE memory size
    #------------------------------------------

    NODE=$1
    DEFAULT_VALUE=$2
    RC=0

    printf "%s\n\n" ""
    read -p "     ${def}Enter the memory size in GB for the $NODE nodes e.g. 12:  ${end} " user_input
    mem_size="${user_input:-$DEFAULT}"
    user_mem_input=$(echo ${mem_size}| grep -o '[[:digit:]]*')
    memory_size=$(echo $user_mem_input*1000|bc)
    confirm "     ${def}You entered${end} ${yel}$user_mem_input${end}${def}, is this correct?${end} ${yel}yes/no${end}"
    if [ "A${response}" == "Ayes" ]
    then
        printf "%s\n" ""
        if [ "A${NODE}" == "Amaster" ]
        then
            sed -i "s/master_mem_size:.*/master_mem_size: "$memory_size"/g" "${ocp4_vars_file}"
        elif [ "A${NODE}" == "Acompute" ]
        then
            sed -i "s/compute_mem_size:.*/compute_mem_size: "$memory_size"/g" "${ocp4_vars_file}"
        else
            printf "%s" "     ${red}Unknown node type $NODE!{end}"
            RC=1
        fi
        printf "%s\n\n" "     ${def}Your $NODE memory size is now set to${end} ${yel}${user_mem_input}G${end}"
    fi
    return $RC

}

function update_node_vcpu_size () {
    #------------------------------------------
    # $NODE vCPU size
    #------------------------------------------

    NODE=$1
    DEFAULT_VALUE=$2
    RC=0

    printf "%s\n\n" ""
    read -p "     ${def}How many vcpu to allocate to the $NODE nodes?${end} " user_input
    user_vcpu="${user_input:-$DEFAULT}"
    user_vcpu_input=$(echo ${user_vcpu}| grep -o '[[:digit:]]*')
    user_vcpu_count=$user_vcpu_input
    confirm "     ${def}You entered${end} ${yel}$user_vcpu_count${end}${def},is this correct?${end} ${yel}yes/no${end}"
    if [ "A${response}" == "Ayes" ]
    then
        printf "%s\n" ""
        if [ "A${NODE}" == "Amaster" ]
        then
            sed -i "s/master_vcpu:.*/master_vcpu: "$user_vcpu_count"/g" "${ocp4_vars_file}"
        elif [ "A${NODE}" == "Acompute" ]
        then
            sed -i "s/compute_vcpu:.*/compute_vcpu: "$user_vcpu_count"/g" "${ocp4_vars_file}"
        else
            printf "%s" "     ${red}Unknown node type $NODE!{end}"
            RC=1
        fi
        printf "%s\n\n" "     ${def}Your $NODE vCPU is now set to${end} ${yel}${user_vcpu_input}.${end}"
    fi
    return $RC

}

function get_cluster_resources () {
    # Get current values
    master_count=$(awk '/^master_count:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    compute_count=$(awk '/^compute_count:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    master_hd_size=$(awk '/^master_hd_size:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    m_mem_size=$(awk '/^master_mem_size:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    master_mem_size=$(echo $m_mem_size/1000|bc)
    master_vcpu=$(awk '/^master_vcpu:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    compute_hd_size=$(awk '/^compute_hd_size:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    c_mem_size=$(awk '/^compute_mem_size:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    compute_mem_size=$(echo $c_mem_size/1000|bc)
    compute_vcpu=$(awk '/^compute_vcpu:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    compute_local_storage=$(awk '/^compute_local_storage:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    compute_vdb_size=$(awk '/^compute_vdb_size:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    compute_vdc_size=$(awk '/^compute_vdc_size:/ {print $2; exit}' "${project_dir}/playbooks/vars/ocp4.yml")
    cluster_custom_opts=("master_count  - ${yel}$master_count${end} master nodes" \
                         "master_disk   - ${yel}$master_hd_size${end} size HD for master nodes" \
                         "master_mem    - ${yel}$master_mem_size${end} memory for master nodes" \
                         "master_vcpu   - ${yel}$master_vcpu${end} vCPU for master nodes" \
                         "compute_count - ${yel}$compute_count${end} compute nodes" \
                         "compute_disk  - ${yel}$compute_hd_size${end} size HD for compute nodes" \
                         "compute_mem   - ${yel}$compute_mem_size${end} memory for compute nodes " \
                         "compute_vcpu  - ${yel}$compute_vcpu${end} vCPU for compute nodes" \
                         "Reset         - Reset to default values" \
                         "Exit          - Save changes and exist")
}

function openshift4_custom_desc () {

cat << EOF



    ${yel}=========================${end}
    ${blu} Deployment Type: Custom${end}
    ${yel}=========================${end}

    ${blu}The Following can be changed${end}

     ${mag}Master Nodes:${end}
       - master node count
       - master disk size
       - master vcpu

     ${mag}Compute Nodes:${end}
       - compute node count
       - compute disk size
       - compute vcpu
       - deploy ocs
         - size for MON disk
         - size for OSD disk
       - deploy local-storage
         - size for disk vdb

    ${red}********** NOTICE ************${end}
    ${blu} This is still in development ${end}
    ${blu} Please resport issues        ${end}
    ${red}******************************${end}


EOF

    all_vars_file="${project_dir}/playbooks/vars/all.yml"
    get_cluster_resources
    printf "%s\n" "    ${blu}Make a selection to change the current value.${end}"
    printf "%s\n\n" "    ${blu}The memory and disk size are in Gigabyte.${end}"
    while true
    do
        createmenu "${cluster_custom_opts[@]}"
        result=($(echo "${selected_option}"))
        case $result in
            master_count) 
                update_node_count master $master_count
                get_cluster_resources
                ;;
            master_disk)
                update_node_disk_size master $master_count
                get_cluster_resources
                ;;
            master_mem)
                update_node_mem_size master $master_mem_size
		get_cluster_resources
                ;;
            master_vcpu)
                update_node_vcpu_size master $master_vcpu_count
		get_cluster_resources
                ;;
            compute_count)
                update_node_count compute $compute_count
                get_cluster_resources
                ;;
            compute_disk)
                update_node_disk_size compute $compute_count
                get_cluster_resources
                ;;
            compute_mem)
                update_node_mem_size compute $compute_mem_size
		get_cluster_resources
                ;;
            compute_vcpu)
                update_node_vcpu_size master $master_vcpu_count
		get_cluster_resources
                ;;
            Reset)
                reset_cluster_resources_default
		get_cluster_resources
                ;;
            Exit) break;;
            * ) echo "Please answer a valid choice";;
        esac
    done

    storage_opts=("NFS   - Configure NFS persistent Storage" \
                  "OCS   - Red Hat OpenShift Container Storage" \
                  "Local - Configure local disk for persistent Storage" \
                  "Reset - Reset to default storage options" \
                  "Exit  - Save changes and exist menu")
    printf "%s\n\n\n" ""
    printf "%s\n\n" "    ${blu}Choose one of the below peristent storage${end}"
    while true
    do
        createmenu "${storage_opts[@]}"
        result=($(echo "${selected_option}"))
        case $result in
            NFS)
                echo NFS
                ;;
            OCS)
                configure_ocs_storage
                ;;
            Local)
                configure_local_storage
                ;;
            Reset)
                echo RESET
                ;;
            Exit)
                break
                ;;
            *)
                echo "Please answer a valid choice"
                ;;
        esac
    done

    ##  set cluster details to custom
    sed -i "s/ocp_cluster_size:.*/ocp_cluster_size: custom/g" "${all_vars_file}"
    sed -i "s/memory_profile:.*/memory_profile: custom/g" "${all_vars_file}"
    sed -i "s/storage_profile:.*/storage_profile: custom/g" "${all_vars_file}"
}

function configure_ocs_storage () {
    #------------------------------------------
    # configure OpenShift Container Storage
    #------------------------------------------
    printf "%s\n\n" ""
    confirm "     ${def}Do you want to deploy OCS? ${end}${yel}yes/no${end}"
    if [ "A${response}" == "Ayes" ]
    then
        read -p "     ${def}Enter the size you want in GB for MON disk, default is 10: ${end} " mon_vdb_size
        read -p "     ${def}Enter the size you want in GB for OSD disk, default is 100: ${end} " osd_vdc_size
        vdb_size="{mon_vdb_size:-10}"
        vdc_size="{osd_vdc_size:-100}"
        compute_vdb_size=$(echo ${vdb_size}| grep -o '[[:digit:]]*')
        compute_vdc_size=$(echo ${vdc_size}| grep -o '[[:digit:]]*')
        confirm "     ${def}You entered${end} ${yel}$compute_vdb_size${end} MON and ${yel}$compute_vdc_size${end} for OSD${def}, is this correct?${end} ${yel}yes/no${end}"
        if [ "A${response}" == "Ayes" ]
        then
            sed -i "s/compute_vdb_size:.*/compute_vdb_size: "$compute_vdb_size"/g" "${ocp4_vars_file}"
            sed -i "s/compute_vdb_size:.*/compute_vdb_size: "$compute_vdb_size"/g" "${ocp4_vars_file}"
            printf "%s\n" ""
            printf "%s" "    ${def}Your MON disk size is set to${end} ${yel}${compute_vdb_size}G${end} and your OSD is set to ${yel}${compute_vdc_size}G${end}"
        fi
    fi
}

function shutdown_variables () {
    export KUBECONFIG=/home/admin/qubinode-installer/ocp4/auth/kubeconfig
    REGISTER_STATUS=$(oc get clusteroperators | awk '/image-registry/ {print $3}')
    CLUSTER_UPTIME=$(oc get clusteroperators | awk '/authentication/ {print $6}')
    CLUSTER_UUID=$(oc get clusterversions.config.openshift.io version -o jsonpath='{.spec.clusterID}{"\n"}')
    INFRA_ID=$(oc get infrastructures.config.openshift.io cluster -o jsonpath='{.status.infrastructureName}{"\n"}')
    BKUP_CMD="sudo /usr/local/bin/etcd-snapshot-backup.sh ./assets/backup/snapshot.db"
    NODE_USER="core"
    SSH_USER=$(whoami)
    USER_SSH_ID="/home/${SSH_USER}/.ssh/id_rsa"
    SSH_OPTIONS="-q -o StrictHostKeyChecking=no -o BatchMode=yes"
    HOURS_RUNNING=$(oc get clusteroperators | awk '/authentication/ {print $6}'|tr -d 'h'|tr -d 'd')
}

function shutdown_nodes () {
    shutdown_variables
    MASTER_ONE=192.168.50.10
    MASTER_STATE=$(ping -c3 ${MASTER_ONE} 1>/dev/null; echo $?)
    
    if [ $MASTER_STATE -ne 0 ]
    then
        printf "\n It appears the cluster is already down.\n\n"
        exit 0
    else
       printf "\ Shutting down the ocp4 cluster.\n"
    fi
    

    for node in $(echo $NODES)
    do
        VM_NAME=$(echo $node|cut -d\. -f1)
        VM_STATE=$(sudo virsh dominfo --domain $VM_NAME | awk '/State/ {print $2}')
        if [ $VM_STATE == "running" ]
        then

            if [ "A${ROLE}" == "Acompute" ]
            then
                # mark node unschedulable
                oc adm cordon $node
                if [ "A$?" != "A0" ]
                then
                    printf "\n Marking $node unschedulable returned $?.\n"
                    printf "\n Please investigate and try again.\n"
                    exit 1
                fi

                # drain node
                oc adm drain $node --ignore-daemonsets --delete-local-data --force --timeout=120s
                if [ "A$?" != "A0" ]
                then
                    printf "\n Draining $node returned $?.\n"
                    printf "\n Continining with shtudwon. Please investigate and try again.\n"
                    # This should prompt the user and ask if they would like t continue with
                    # shutdown or exist and troubleshoot.
                    #exit 1
                fi
            fi 

            printf "\n\n Shutting down $node.\n"
            ssh $SSH_OPTIONS -i $USER_SSH_ID "${NODE_USER}@${node}" sudo shutdown -h now --no-wall

            until [ $VM_STATE != "running" ]
            do
                printf "\n Waiting on $VM_NAME to shutdown. \n"
                VM_STATE=$(sudo virsh dominfo --domain $VM_NAME | awk '/State/ {print $2}')
                sleep 5s
            done
            printf "\n $VM_NAME state is $VM_STATE\n\n"
        else 
            printf "\n $VM_NAME state is $VM_STATE\n\n"
        fi
    done
}

function shutdown_cluster () {
    shutdown_variables
    if [ $HOURS_RUNNING -gt 24 ]
    then
    
        printf "\n The ocp4 cluster has been up for more than 24hrs now.\n The current uptime is ${HOURS_RUNNING}\n\n"
        ALL_COMPUTES=$(oc get nodes -l node-role.kubernetes.io/worker="" --no-headers | awk '{print $1}'|sort -r)
        ALL_MASTERS=$(oc get nodes -l node-role.kubernetes.io/master="" --no-headers | awk '{print $1}'|sort -r)
    
        printf "\n Backing up etcd snapshot.\n\n"
        ssh $SSH_OPTIONS -i $USER_SSH_ID "${NODE_USER}@${MASTER_ONE}" $BKUP_CMD tar tar czf - /home/core/assets/ > /home/${SSH_USER}/ocp4-etcd-snapshot-$(date +%Y%m%d-%H%M%S).tar.gz
    
        # Mark computes as unscheduleable, drain and shutdown
        ROLE=compute
        NODES=$ALL_COMPUTES
        shutdown_nodes 
    
        ROLE=master
        NODES=$ALL_MASTERS
        shutdown_nodes 
    else
        printf "\n The ocp4 cluster has been up for less that 24hrs now.\n Please wait until after 24rs beforetrying to shutdown the cluster.\n\n"
    fi
    
    exit 0

}

openshift4_server_maintenance () {
    case ${product_maintenance} in
       diag)
           echo "Perparing to run full Diagnostics: : not implemented yet"
           ;;
       smoketest)
           echo  "Running smoke test on environment: : not implemented yet"
              ;;
       shutdown)
            shutdown_cluster
            ;;
       startup)
            ansible-playbook ${project_dir}/playbooks/deploy_ocp4.yml -t startup -e startup_cluster=yes || exit 1
            /usr/local/bin/qubinode-ocp4-status
            ;;
       status)
            /usr/local/bin/qubinode-ocp4-status
            ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}
