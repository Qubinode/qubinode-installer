#!/bin/bash

function openshift4_variables () {
    ocp4_vars_file="${project_dir}/playbooks/vars/ocp4.yml"
    ocp4_sample_vars="${project_dir}/samples/ocp4.yml"
    ocp4_pull_secret="${project_dir}/pull-secret.txt"
}

function openshift4_prechecks () {
    openshift4_variables
    if [ ! -f "${ocp4_vars_file}" ]
    then
        cp "${ocp4_sample_vars}" "${ocp4_vars_file}"
    fi

    #check for pull secret
    if [ ! -f "${ocp4_pull_secret}" ]
    then
        echo "Please download your pull-secret from: "
        echo "https://cloud.redhat.com/openshift/install/metal/user-provisioned"
        echo "and save it as ${ocp4_pull_secret}"
        echo ""
        exit
    fi

    check_for_required_role openshift-4-loadbalancer
    check_for_required_role swygue.coreos-virt-install-iso

    # Ensure firewall rules
    if ! sudo firewall-cmd --list-ports | grep -q '32700/tcp'
    then
        echo "Setting firewall rules"
        sudo firewall-cmd --add-port={8080/tcp,80/tcp,443/tcp,6443/tcp,22623/tcp,32700/tcp} --permanent
        sudo firewall-cmd --reload
    fi

    curl -OL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/release.txt
    current_version=$(cat release.txt | grep Name:  |  awk '{print $2}')
    sed -i "s/^ocp4_version:.*/ocp4_version: ${current_version}/"   "${project_dir}/playbooks/vars/ocp4.yml"

}

openshift4_qubinode_teardown () {
    # delete dns entries
    ansible-playbook playbooks/ocp4_02_configure_dns_entries.yml -e tear_down=true

    # Delete VMS
    test -f $ocp4_vars_file && remove_ocp4_vms

    # Delete containers managed by systemd
    for i in $(echo "lbocp42.service ocp4lb.service openshift-4-loadbalancer-ocp42.service")
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
    containers=( ocp4lb lbocp42 openshift-4-loadbalancer-ocp42 ocp4ignhttpd ignwebserver)
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
        exit
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

function isvmRunning () {
    sudo virsh list |grep $vm|awk '/running/ {print $2}'
}

function isvmShutdown () {
    sudo virsh list --all | grep $vm| awk '/shut/ {print $2}'
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
        exit
    fi
}

openshift4_server_maintenance () {
    echo "Hello World"
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
    sleep 10s
}

deploy_master_nodes () {
    ## Deploy Master
    for i in {0..2}
    do
        MASTER=$(sudo virsh net-dumpxml ocp42 | grep  master-${i} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
        COREOS_IP=$(sudo virsh net-dumpxml ocp42 | grep  master-${i} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
        ansible-playbook playbooks/ocp4_07.1_deploy_master_vm.yml  -e vm_mac_address=${MASTER}   -e vm_name=master-${i} -e coreos_host_ip=${COREOS_IP}
        sleep 10s
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
  build_ocp4_vm_list
  for vm in ${all_vms[@]}
  do
      isvmRunning | while read VM
      do
          printf "%s\n" " waiting for $vm first boot shutdown to complete"
          sleep 10s
      done
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


post_deployment_steps (){
  echo "Shutdown bootstrap node"
  echo "*****************************"
  echo "sudo virsh shutdown bootstrap"

  echo "Check openshift enviornment and monitor clusteroperator status"
  echo "*****************************"
  cat << EOF
  # export KUBECONFIG=/home/admin/qubinode-installer/ocp4/auth/kubeconfig
  # oc whoami
  # oc get nodes
  # oc get csr
  # oc get clusteroperators
EOF

echo "NFS Server mount directory information"
ls -lath /export
df -h /export

confirm "Configure nfs-provisioner? yes/no"
if [ "A${response}" != "Ayes" ]
then
  export KUBECONFIG=/home/admin/qubinode-installer/ocp4/auth/kubeconfig
    oc get storageclass
    bash lib/qubinode_nfs_provisioner_setup.sh
    oc get storageclass || exit 1
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

cat << EOF
# Please Follow instructions located below for persistent registry storage
# Link: https://docs.openshift.com/container-platform/4.2/registry/configuring-registry-storage/configuring-registry-storage-baremetal.html
EOF
else
  echo "Skipping nfs-provisioning"
  echo "Optional: Configure registry to use empty directory if you do not want to use the nfs-provisioner"
  echo "*****************************"
  cat << EOF
  # oc get pod -n openshift-image-registry
  # oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'
  # oc get pod -n openshift-image-registry
  # oc get clusteroperators
EOF
fi

echo "Check that OpenShift installation is complete"
echo "*****************************"
cat << EOF
# cd ~/qubinode-installer
# openshift-install --dir=ocp4 wait-for install-complete
EOF

}

openshift4_enterprise_deployment () {

    # declare variables
    cluster_name=$(awk '/^cluster_name/ {print $2; exit}' "${ocp4_vars_file}")
    lb_name=$(awk '/^lb_name/ {print $2; exit}' "${ocp4_vars_file}")
    podman_webserver=$(awk '/^podman_webserver/ {print $2; exit}' "${ocp4_vars_file}")
    lb_container_name="${lb_name}-${cluster_name}"

    # Ensure all preqs before continuing
    openshift4_prechecks

    # Setup the host system
    ansible-playbook playbooks/ocp4_01_deployer_node_setup.yml || exit 1

    # populate IdM with the dns entries required for OCP4
    ansible-playbook playbooks/ocp4_02_configure_dns_entries.yml  || exit 1

    # deploy the load balancer container
    ansible-playbook playbooks/ocp4_03_configure_lb.yml  || exit 1

    lb_container_status=$(sudo podman inspect -f '{{.State.Running}}' $lb_container_name 2>/dev/null)
    if [ "A${lb_container_status}" != "Atrue" ]
    then
        printf "%s\n" " The load balancer container ${cyn}$lb_container_name${end} did not deploy."
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
