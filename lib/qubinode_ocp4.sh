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
        sudo firewall-cmd --add-port={80/tcp,443/tcp,6443/tcp,22623/tcp,32700/tcp} --permanent
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
    for n in $(cat rhcos-install/node-list)
    do
        echo "Deleting VM $n..."
        sudo virsh shutdown $n
        sleep 10s
        sudo virsh destroy $n
        sudo virsh undefine $n
        sudo rm -f /var/lib/libvirt/images/${n}.qcow2
    done

    test -d "${project_dir}/ocp4" && rm -rf "${project_dir}/ocp4"
    test -d "${project_dir}/rhcos-install" && rm -rf "${project_dir}/rhcos-install"

    if sudo podman ps -a| grep -q ocp4lb
    then
        echo "Removing ocp4lb container."
        sudo podman stop ocp4lb
        sudo podman rm ocp4lb
    fi

    if sudo podman ps -a| grep -q lbocp42
    then
        echo "Removing lbocp42 container."
        sudo podman stop lbocp42
        sudo podman rm lbocp42
    fi

    if sudo podman ps -a| grep -q openshift-4-loadbalancer-ocp42
    then
        echo "Removing openshift-4-loadbalancer-ocp42 container."
        sudo podman stop openshift-4-loadbalancer-ocp42
        sudo podman rm openshift-4-loadbalancer-ocp42
    fi

    if sudo podman ps -a| grep -q ocp4ignhttpd
    then
        sudo podman stop ocp4ignhttpd
        sudo podman rm ocp4ignhttpd
    fi

    if sudo podman ps -a| grep -q ocp4ignhttpd
    then
        sudo podman stop openshift-4-loadbalancer-ocp42
        sudo podman rm openshift-4-loadbalancer-ocp42
    fi

    test -d /opt/qubinode_webserver/4.2/ignitions && \
         rm -rf /opt/qubinode_webserver/4.2/ignitions

for i in $(echo "lbocp42.service ocp4lb.service openshift-4-loadbalancer-ocp42.service")
do
    echo "Removing podman container $i"
    sudo systemctl stop $i
    sudo systemctl disable $i
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
done

test -d "${project_dir}/playbooks/vars/ocp4.yml"  && rm -f "${project_dir}/playbooks/vars/ocp4.yml"
    echo ""
    echo "OCP4 deployment removed"
    exit 0
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

wait_for_nodes (){
  i="$(sudo virsh list | grep running |wc -l)"

  while [ $i -gt 1 ]
  do
    echo "waiting for coreos first boot to complete current count ${i}"
    sleep 10s
    i="$(sudo virsh list | grep running |wc -l)"
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


  echo "Configure registry to use empty directory"
  echo "*****************************"
  cat << EOF
  # oc get pod -n openshift-image-registry
  # oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'
  # oc get pod -n openshift-image-registry
  # oc get clusteroperators
EOF

  echo "Check that OpenShift installation is complete"
  echo "*****************************"
  cat << EOF
  # cd ~/qubinode-installer
  # openshift-install --dir=ocp4 wait-for install-complete
EOF

}

openshift4_enterprise_deployment () {
    openshift4_prechecks
    ansible-playbook playbooks/ocp4_01_deployer_node_setup.yml || exit 1
    ansible-playbook playbooks/ocp4_02_configure_dns_entries.yml  || exit 1
    ansible-playbook playbooks/ocp4_03_configure_lb.yml  || exit 1
    sudo podman ps || exit 1
    ansible-playbook playbooks/ocp4_04_download_openshift_artifacts.yml  || exit 1
    ansible-playbook playbooks/ocp4_05_create_ignition_configs.yml || exit 1
    ansible-playbook playbooks/ocp4_06_deploy_webserver.yml  || exit 1
    NODE_NETINFO=$(mktemp)
    sudo virsh net-dumpxml ocp42 | grep 'host mac' > $NODE_NETINFO
    deploy_bootstrap_node
    deploy_master_nodes
    deploy_compute_nodes
    wait_for_nodes
    start_ocp4_deployment
    post_deployment_steps
}
