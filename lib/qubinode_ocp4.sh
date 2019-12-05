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
}

openshift4_qubinode_teardown () {
    echo "Hello World"
}

openshift4_server_maintenance () {
    echo "Hello World"
}

is_node_up () {
    IP=$1
    VMNAME=$2
    NAME_CHECK=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" core@${IP} 'hostname -s')
    ETCD_CHECK=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" core@${IP} 'dig @172.24.24.10 -t srv _etcd-server-ssl._tcp.ocp42.lunchnet.example|grep "^_etcd-server-ssl."|wc -l
')
    if [ "A${VMNAME}" != "A${NAME_CHECK}" ]
    then
        echo "Could not determine if $VMNAME was properly deployed."
        exit 1
    else
        echo "$VMNAME was properly deployed"
    fi
}


deploy_bootstrap_node () {
    # Deploy Bootstrap
    DOMINFO=$(mktemp)
    VMNAME=bootstrap
    sudo virsh dominfo $VMNAME > $DOMINFO 2>/dev/null
    NODE_NETINFO=$(mktemp)
    sudo virsh net-dumpxml ocp42 | grep 'host mac' > $NODE_NETINFO
    BOOTSTRAP_NODE_MAC=$(awk -F"'" '/bootstrap/ {print $2}' $NODE_NETINFO)
    BOOTSTRAP_NODE_IP=$(awk -F"'" '/bootstrap/ {print $6}' $NODE_NETINFO)
    if grep -q "shut off" $DOMINFO
    then
        #TODO: add option to only start VM if the cluster has not been deployed
        echo "The bootstrap node appears to be deploy but powered off"
        sudo virsh start $VMNAME
        is_node_up $BOOTSTRAP_NODE_IP $VMNAME
    elif grep -q "running" $DOMINFO
    then
        echo "The boostrap node appears to be running"
        is_node_up $BOOTSTRAP_NODE_IP $VMNAME
    else
        ansible-playbook playbooks/ocp4_07_deploy_bootstrap_vm.yml  -e vm_mac_address=${BOOTSTRAP_NODE_MAC} -e coreos_host_ip=${BOOTSTRAP_NODE_IP}
        sudo virsh start $VMNAME
        is_node_up $BOOTSTRAP_NODE_IP $VMNAME
    fi
}

deploy_master_nodes () {    
    ## Deploy Master
    MASTER_COUNT=$(grep master $NODE_NETINFO|wc -l)
    COUNTER=0
    while [  $COUNTER -lt $MASTER_COUNT ]; do
        NODE="master-${COUNTER}"
        #NODE=$(grep $NODE $NODE_NETINFO | awk -F"'" '{print $4}'|cut -d'.' -f1)
        MASTER_NODE_MAC=$(grep $NODE $NODE_NETINFO | awk -F"'" '{print $2}')
        MASTER_NODE_IP=$(grep $NODE $NODE_NETINFO | awk -F"'" '{print $6}')
        echo "ansible-playbook playbooks/ocp4_07.1_deploy_master_vm.yml -e vm_mac_address=${MASTER_NODE_MAC} -e vm_name=${NODE} -e coreos_host_ip=${MASTER_NODE_IP}"
        #sleep 10s
        let COUNTER=COUNTER+1 
    done
}

deploy_compute_nodes () {
    # Deploy computes
    COMPUTE_COUNT=$(grep compute- $NODE_NETINFO|wc -l)
    COUNTER=0
    while [  $COUNTER -lt $COMPUTE_COUNT ]; do
        NODE="compute-${COUNTER}"
        COMPUTE_NODE_MAC=$(grep $NODE $NODE_NETINFO |awk -F"'" '{print $2}')
        COMPUTE_NODE_IP=$(grep $NODE $NODE_NETINFO |awk -F"'" '{print $6}')
        echo "ansible-playbook playbooks/ocp4_07.2_deploy_compute_vm.yml -e vm_mac_address=${COMPUTE_NODE_MAC} -e vm_name=${NODE} -e coreos_host_ip=${COMPUTE_NODE_IP}"
        #sleep 10s
        let COUNTER=COUNTER+1 
    done

    echo $NODE_NETINFO    
    i="$(sudo virsh list | grep running |wc -l)"
    while [ $i -gt 1 ]
    do
        echo "waiting for coreos first boot to complete current count ${i}"
        sleep 10s
        i="$(sudo virsh list | grep running |wc -l)"
    done
}

openshift4_enterprise_deployment () {
    openshift4_prechecks
    ansible-playbook playbooks/ocp4_01_deployer_node_setup.yml
    ansible-playbook playbooks/ocp4_02_configure_dns_entries.yml
    ansible-playbook playbooks/ocp4_03_configure_lb.yml
    ansible-playbook playbooks/ocp4_04_download_openshift_artifacts.yml
    ansible-playbook playbooks/ocp4_05_create_ignition_configs.yml
    ansible-playbook playbooks/ocp4_06_deploy_webserver.yml 
    deploy_bootstrap_node
}
