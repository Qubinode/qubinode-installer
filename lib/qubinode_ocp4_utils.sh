#!/bin/bash

function openshift4_variables () {
    ocp4_pull_secret="${project_dir}/pull-secret.txt"
    cluster_name=$(awk '/^cluster_name/ {print $2; exit}' "${ocp4_vars_file}")
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

function openshift4_prechecks () {
    ocp4_vars_file="${project_dir}/playbooks/vars/ocp4.yml"
    ocp4_sample_vars="${project_dir}/samples/ocp4.yml"
    if [ ! -f "${ocp4_vars_file}" ]
    then
        cp "${ocp4_sample_vars}" "${ocp4_vars_file}"
    fi
    openshift4_variables


    check_for_required_role openshift-4-loadbalancer
    check_for_required_role swygue.coreos-virt-install-iso

    # Ensure firewall rules
    if ! sudo firewall-cmd --list-ports | grep -q '32700/tcp'
    then
        echo "Setting firewall rules"
        sudo firewall-cmd --add-port={8080/tcp,80/tcp,443/tcp,6443/tcp,22623/tcp,32700/tcp} --permanent
        sudo firewall-cmd --reload
    fi

    curl -sOL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/release.txt
    current_version=$(cat release.txt | grep Name:  |  awk '{print $2}')
    sed -i "s/^ocp4_version:.*/ocp4_version: ${current_version}/"   "${project_dir}/playbooks/vars/ocp4.yml"

    # Ensure Openshift Subscription Pool is attached
    check_for_openshift_subscription
    get_subscription_pool_id 'Red Hat OpenShift Container Platform'

}

openshift4_qubinode_teardown () {

    # Ensure all preqs before continuing
    openshift4_prechecks

    # delete dns entries
    ansible-playbook playbooks/ocp4_02_configure_dns_entries.yml -e tear_down=true

    # Delete VMS
    test -f $ocp4_vars_file && remove_ocp4_vms

    # Delete containers managed by systemd
    for i in $(echo "lbocp42.service ocp4lb.service $podman_webserver $lb_name")
    do
        if sudo sudo systemctl list-unit-files | grep -q $i
        then
            echo "Removing podman container $i"
            sudo systemctl stop $i >/dev/null
            sudo systemctl disable $i >/dev/null
            sudo systemctl daemon-reload >/dev/null
            sudo systemctl reset-failed >/dev/null
            path="/etc/systemd/system/${i}"
            test -f $path && sudo rm -f $path
        fi
    done


    # Delete the remaining containers and pruge their images
    containers=(ocp4lb lbocp42 openshift-4-loadbalancer-ocp42 ocp4ignhttpd ignwebserver qbn-httpd)
    deleted_containers=()
    for pod in ${containers[@]}
    do
        id=$(sudo podman ps -q -f name=$pod)
        if [ "A${id}" != "A" ]
        then
            sudo podman container stop $id
            sudo podman container rm -f $id
        fi

        if ! sudo podman container ls -a | grep -q $pod
        then
            deleted_containers+=( "$pod" )
            containers=("${containers[@]/$pod/}")
        fi
    done

    # purge all containers and their images
    sudo podman container prune --force >/dev/null
    sudo podman image prune --all >/dev/null

    # Verify all containers have been deleted and exit otherwise
    if [ "${#containers[@]}" -ne "${#deleted_containers[@]}" ]
    then
        printf "%s\n" " There is a total of ${#containers[@]}, ${#deleted_containers[@]} were deleted."
        printf "%s\n" " The following could containers not be deleted. Please manually delete them and try again."

        for i in "${containers[@]}"
        do
            printf "%s\n" "    ${i:-other}"|grep -v other
        done
        exit 0
    fi

    # Remove downloaded ignitions files
    test -d /opt/qubinode_webserver/4.2/ignitions && \
         rm -rf /opt/qubinode_webserver/4.2/ignitions
    test -d "${project_dir}/ocp4" && rm -rf "${project_dir}/ocp4"
    test -d "${project_dir}/rhcos-install" && rm -rf "${project_dir}/rhcos-install"
    test -f "${project_dir}/playbooks/vars/ocp4.yml"  && rm -f "${project_dir}/playbooks/vars/ocp4.yml"

    printf "%s\n\n" ""
    printf "%s\n" " ${yel}************************${end}"
    printf "%s\n" " OCP4 deployment removed"
    printf "%s\n\n" " ${yel}************************${end}"
    exit 0
}

function remove_ocp4_vms () {
    #clean up
    all_vms=(bootstrap)
    deleted_vms=()

    masters=$(cat $ocp4_vars_file | grep master_count| awk '{print $2}')
    for  i in $(seq "$masters")
    do
        vm="master-$((i-1))"
        all_vms+=( "$vm" )
    done

    compute=$(cat $ocp4_vars_file | grep compute_count| awk '{print $2}')
    for i in $(seq "$compute")
    do
        vm="compute-$((i-1))"
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

openshift4_server_maintenance () {
    case ${product_maintenance} in
       diag)
           echo "Perparing to run full Diagnostics: : not implemented yet"
           ;;
       smoketest)
           echo  "Running smoke test on environment: : not implemented yet"
              ;;
       shutdown)
            echo  "Shutting down cluster"
            bash "${project_dir}/openshift4_server_maintenance"
            ;;
       startup)
            echo  "Starting up Cluster: not implemented yet"
            ;;
       checkcluster)
            echo  "Running Cluster health check: : not implemented yet"
            ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
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
    ETCD_CHECK=$(ssh core@${IP} 'dig @${DNSIP} -t srv _etcd-server-ssl._tcp.ocp42.lunchnet.example|grep "^_etcd-server-ssl."|wc -l')
    echo ETCD_CHECK=$ETCD_CHECK
    if [ "A${VMNAME}" != "A${NAME_CHECK}" ]
    then
      hostnamectl set-hostname "${VMNAME}.ocp42.${domain}"
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
    web_console="https://console-openshift-console.apps.ocp42.${domain}"
    WEBCONSOLE_STATUS=$(curl --write-out %{http_code} --silent --output /dev/null "${web_console}" --insecure)
    return $WEBCONSOLE_STATUS
}

function pingreturnstatus() {
  ping -q -c3 $1 > /dev/null

  if [ $? -eq 0 ]
  then
    true
  else
    false
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
    #sudo virsh net-dumpxml ocp42 | grep 'host mac' > $NODE_NETINFO
    BOOTSTRAP=$(sudo virsh net-dumpxml ocp42 | grep  bootstrap | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
    COREOS_IP=$(sudo virsh net-dumpxml ocp42 | grep  bootstrap  | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
    ansible-playbook playbooks/ocp4_07_deploy_bootstrap_vm.yml  -e vm_mac_address=${BOOTSTRAP} -e coreos_host_ip=${COREOS_IP}
    sleep 30s
}

deploy_master_nodes () {
    ## Deploy Master
    for i in {0..2}
    do
        MASTER=$(sudo virsh net-dumpxml ocp42 | grep  master-${i} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
        COREOS_IP=$(sudo virsh net-dumpxml ocp42 | grep  master-${i} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
        ansible-playbook playbooks/ocp4_07.1_deploy_master_vm.yml  -e vm_mac_address=${MASTER}   -e vm_name=master-${i} -e coreos_host_ip=${COREOS_IP}
        sleep 30s
    done

}

deploy_compute_nodes () {
    # Deploy computes
    for i in {0..1}
    do
      COMPUTE=$(sudo virsh net-dumpxml ocp42 | grep  compute-${i} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
      COREOS_IP=$(sudo virsh net-dumpxml ocp42 | grep   compute-${i} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
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

post_deployment_steps () {

    # ugly hack to install the jq command from the ocp 4.2 repo
    # when we move ocp3 to jumpbox, this no longer needs to be a hack
    if ! rpm -qa | grep -q 'jq-'
    then
        sudo subscription-manager repos --enable rhel-7-server-ose-4.2-rpms
        rpmdir=$(mktemp -d)
        sudo yumdownloader --resolve --destdir=${rpmdir} oniguruma jq
        sudo subscription-manager repos --disable rhel-7-server-ose-4.2-rpms
        sudo yum -y install ${rpmdir}/*.rpm
     fi

    printf "%s\n\n" ""
    printf "%s\n" " Registry storage for bate metal is required to complete the ocp4 cluster install."
    printf "%s\n" " Additional informaiton is available here:"
    printf "%s\n\n" " https://red.ht/2QVJpPK"
    printf "%s\n" " The installer will attempt to configure storage."

    if sudo rpcinfo -t localhost nfs 4 > /dev/null 2>&1
    then
        printf "%s\n\n" ""
        printf "%s\n" " NFS Server is configured and can be used for persistent storage."
        confirm " Do you want to configure nfs-provisioner? yes/no"
        if [ "A${response}" == "Ayes" ]
        then
            export KUBECONFIG="${project_dir}/ocp4/auth/kubeconfig"
            if ! oc get storageclass | grep -q nfs-storage
            then
                bash ${project_dir}/lib/qubinode_nfs_provisioner_setup.sh
            fi

            if oc get storageclass | grep -q nfs-storage
            then
cat >image-registry-storage.yaml<<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: image-registry-storage
spec:
  accessModes:
  - ReadWriteMany
  storageClassName: nfs-storage-provisioner
  resources:
    requests:
      storage: 80Gi
YAML
                oc create -f image-registry-storage.yaml
                sleep .5s
                # Add pvc claim for registry storage
                oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{\"spec\":{\"storage\":{\"pvc\":{}}}}'

                # Verify claim
                sleep .5s
                if oc get configs.imageregistry.operator.openshift.io -o json | jq .items[0].spec.storage | grep -q image-registry-storage
                then
                    printf "%sn" " Registry pvc claim created successfully"
                fi
            else
                printf "%s\n" " ${red}Unable to add nfs storage provisioner, please investigate.${end}"
                empty_directory_msg
            fi
         fi
    else
      printf "%s\n" " Skipping nfs-provisioning"
      printf "%s\n\n" "*****************************"
      printf "%s\n" "Optional: Configure registry to use empty directory if you do not want to use the nfs-provisioner"
      empty_directory_msg
    fi
    printf "%s\n" " ${yel}*****************************${end}"
    printf "%s\n" " ${cyn}   Post Bootstrap Steps ${end}"
    printf "%s\n\n" " ${yel}*****************************${end}"
    printf "%s\n" " (1) Shutdown the bootstrap node."
    printf "%s\n\n" "       ${grn}sudo virsh shutdown bootstrap${end}"
    printf "%s\n" " (2) Ensure all nodes are up."
    printf "%s\n" "       ${grn}export KUBECONFIG=${project_dir}/ocp4/auth/kubeconfig${end}"
    printf "%s\n\n" "       ${grn}oc get nodes${end}"
    printf "%s\n" " (3) Ensure there are no pending CSR."
    printf "%s\n\n" "       ${grn}oc get csr${end}"
    printf "%s\n" " (4) Ensure a storage claim exist for the imageregistry"
    printf "%s\n" "       ${grn}oc get configs.imageregistry.operator.openshift.io -o json | jq .items[0].spec.storage${end}"
    printf "%s\n" " The above command output should return:"
cat << EOF
                    {
                      "pvc": {
                        "claim": "image-registry-storage"
                      }
                    }
EOF
    printf "%s\n" " If the output differs you can delete whats there."
    printf "%s\n" "       ${grn}oc patch configs.imageregistry.operator.openshift.io cluster --type json -p '[{ \"op\": \"remove\", \"path\": \"/spec/storage/pvc\" }]'${end}"
    printf "%s\n" " Then try adding the nfs storage, then check again if the output matches."
    printf "%s\n" "       ${grn}oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{\"spec\":{\"storage\":{\"pvc\":{}}}}'${end}"
    printf "%s\n" " If there's still no match the imageregistry operator is still down (step 5). Try setting it to a emptydir."
    printf "%s\n\n" "       ${grn}oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{\"spec\":{\"storage\":{\"emptyDir\":{}}}}'${end}"
    printf "%s\n" " (5) Ensure the image-registry operator ${yel}AVAILABLE${end} shows ${yel}True${end}."
    printf "%s\n\n" "       ${grn}oc get clusteroperators image-registry${end}"
    printf "%s\n" " (6) Ensure all operatators ${yel}AVAILABLE${end} shows ${yel}True${end}."
    printf "%s\n\n" "       ${grn}oc get clusteroperator${end}"
    printf "%s\n" " (7) If all the above checks out, complete the installation by running."
    printf "%s\n" "       ${grn}cd ${project_dir}${end}"
    printf "%s\n\n" "       ${grn}openshift-install --dir=ocp4 wait-for install-complete${end}"
}

openshift4_kvm_health_check (){
  KVM_IN_GOOD_HEALTH="not ready"

  #requested_brigde=$(cat ${vars_file}|grep  vm_libvirt_net: | awk '{print $2}' | sed 's/"//g')
  if sudo virsh net-list | grep -q $requested_brigde; then
    echo "$requested_brigde is configured"
  else
      KVM_IN_GOOD_HEALTH=ready
  fi

  requested_nat=$(cat ${vars_file}|grep  cluster_name: | awk '{print $2}' | sed 's/"//g')
  if sudo virsh net-list | grep -q $requested_nat; then
    echo "$requested_nat is configured"
  else
      KVM_IN_GOOD_HEALTH=ready
  fi

  if sudo lsblk | grep -q nvme0n1; then
    echo "Checking for vg name "
    #vg_name=$(cat ${vars_file}| grep vg_name: | awk '{print $2}')
    if sudo vgdisplay | grep -q $vg_name; then
      echo "$vg_name is configured"
    else
        KVM_IN_GOOD_HEALTH=ready
    fi
  else
      echo "Skipping mount path check"
  fi

  check_image_path=$(cat ${vars_file}| grep kvm_host_libvirt_dir: | awk '{print $2}')
  if [[ -d $check_image_path ]]; then
    echo "$check_image_path exists"
  else
    KVM_IN_GOOD_HEALTH=ready
  fi

  libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/playbooks/vars/kvm_host.yml")
  os_qcow_image_name=$(awk '/^os_qcow_image_name/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
  if sudo bash -c '[[ ! -f '${libvirt_dir}'/'${os_qcow_image_name}' ]]'; then
    KVM_IN_GOOD_HEALTH="not ready"
  fi
  
  printf "%s\n\n" "  The KVM host health status is $KVM_IN_GOOD_HEALTH."
}

openshift4_idm_health_check () {
IDM_IN_GOOD_HEALTH=ready

if [[ -f $idm_vars_file ]]; then
  echo "$idm_vars_file exists"
else
  IDM_IN_GOOD_HEALTH="not ready"
fi

idm_ipaddress=$(cat ${idm_vars_file} | grep idm_server_ip: | awk '{print $2}')
if pingreturnstatus ${idm_ipaddress}; then
  echo "IDM Server is connected $idm_ipaddress"
else
  IDM_IN_GOOD_HEALTH="not ready"
fi

dns_query=$(dig +short @${idm_ipaddress} qbn-dns01.${domain})
echo "dns_query = $dns_query"
if echo $dns_query | grep -q 'no servers could be reached'
then
      IDM_IN_GOOD_HEALTH="not ready"
else
      echo "IDM Server is able to resolve qbn-dns01.${domain}"
      echo $dns_query
fi

  printf "%s\n\n" "  The IdM host health status is $IDM_IN_GOOD_HEALTH."
}


function ping_openshift4_nodes () {
    IS_OPENSHIFT4_NODES="not ready"
    masters=$(cat $ocp4_vars_file | grep master_count| awk '{print $2}')
    for  i in $(seq "$masters")
    do
        vm="master-$((i-1))"
        if  pingreturnstatus ${vm}.ocp42.${domain}; then
          echo "${vm}.ocp42.lab.example is online"
          IS_OPENSHIFT4_NODES=ready
        else
          echo "${vm}.ocp42.lab.example is offline"
          IS_OPENSHIFT4_NODES="not ready"
          break
        fi
    done

    compute=$(cat $ocp4_vars_file | grep compute_count| awk '{print $2}')
    for i in $(seq "$compute")
    do
        vm="compute-$((i-1))"
        if  pingreturnstatus ${vm}.ocp42.${domain}; then
          echo "${vm}.ocp42.lab.example is online"
          IS_OPENSHIFT4_NODES=ready
        else
          echo "${vm}.ocp42.lab.example is offline"
          IS_OPENSHIFT4_NODES="not ready"
          break
        fi
    done

    printf "%s\n\n" "  The OCP4 nodes health status is $IS_OPENSHIFT4_NODES."
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
    sudo virsh net-dumpxml ocp42 | grep 'host mac' > $NODE_NETINFO

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
