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

    ansible-playbook playbooks/ocp4_02_configure_dns_entries.yml -e tear_down=true
    for n in $(cat rhcos-install/node-list)
    do 
        sudo virsh shutdown $n;sleep 10s; sudo virsh undefine $n
    done
   
    test -d "${project_dir}/ocp4" && rm -rf "${project_dir}/ocp4" 
    test -d "${project_dir}/rhcos-install" && rm -rf "${project_dir}/rhcos-install" 

    if sudo podman ps -a| grep -q ocp4lb
    then
        sudo podman stop ocp4lb
        sudo podman rm ocp4lb
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
}

openshift4_server_maintenance () {
    echo "Hello World"
}

is_node_up () {
    IP=$1
    VMNAME=$2
    WAIT_TIME=0
    until ping -c4 "${NODE_IP}" >& /dev/null || [ $WAIT_TIME -eq 60 ]
    do
        sleep $(( WAIT_TIME++ ))
    done
    ssh -q -o "StrictHostKeyChecking=no" core@${IP} 'hostname -s' &>/dev/null
    NAME_CHECK=$(ssh core@${IP} 'hostname -s')
    #NAME_CHECK=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" core@${IP} 'hostname -s')
    ETCD_CHECK=$(ssh core@${IP} 'dig @172.24.24.10 -t srv _etcd-server-ssl._tcp.ocp42.lunchnet.example|grep "^_etcd-server-ssl."|wc -l')
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
    NODE_MAC=$(awk -F"'" '/bootstrap/ {print $2}' $NODE_NETINFO)
    NODE_IP=$(awk -F"'" '/bootstrap/ {print $6}' $NODE_NETINFO)
    ignite_node ocp4_07_deploy_bootstrap_vm.yml
}

deploy_master_nodes () {    
    ## Deploy Master
    MASTER_COUNT=$(grep master $NODE_NETINFO|wc -l)
    COUNTER=0
    while [  $COUNTER -lt $MASTER_COUNT ]; do
        DOMINFO=$(mktemp)
        VMNAME="master-${COUNTER}"
        sudo virsh dominfo $VMNAME > $DOMINFO 2>/dev/null
        #NODE_NETINFO=$(mktemp)
        #sudo virsh net-dumpxml ocp42 | grep 'host mac' > $NODE_NETINFO
        NODE_MAC=$(awk -v var="${VMNAME}" -F"'" '$0 ~ var  {print $2}' $NODE_NETINFO)
        NODE_IP=$(awk -v var="${VMNAME}" -F"'" '$0 ~ var {print $6}' $NODE_NETINFO)
        ignite_node ocp4_07.1_deploy_master_vm.yml
        let COUNTER=COUNTER+1 
    done
}

deploy_compute_nodes () {
    # Deploy computes
    COMPUTE_COUNT=$(grep compute- $NODE_NETINFO|wc -l)
    COUNTER=0
    sleep 10s
    while [  $COUNTER -lt $COMPUTE_COUNT ]; do
        DOMINFO=$(mktemp)
        VMNAME="compute-${COUNTER}"
        sudo virsh dominfo $VMNAME > $DOMINFO 2>/dev/null
        NODE_MAC=$(awk -v var="${VMNAME}" -F"'" '$0 ~ var  {print $2}' $NODE_NETINFO)
        NODE_IP=$(awk -v var="${VMNAME}" -F"'" '$0 ~ var {print $6}' $NODE_NETINFO)
        ignite_node ocp4_07.2_deploy_compute_vm.yml
        let COUNTER=COUNTER+1 
    done
}

start_ocp4_deployment () {
    ignition_dir="${project_dir}/ocp4"
    install_cmd=$(mktemp)
    cd "${project_dir}"
    echo "openshift-install --dir=${ignition_dir} wait-for bootstrap-complete --log-level debug" > $install_cmd
    bash $install_cmd
}

openshift4_enterprise_deployment () {
    #openshift4_prechecks
    #ansible-playbook playbooks/ocp4_01_deployer_node_setup.yml
    #ansible-playbook playbooks/ocp4_02_configure_dns_entries.yml
    #ansible-playbook playbooks/ocp4_03_configure_lb.yml
    #ansible-playbook playbooks/ocp4_04_download_openshift_artifacts.yml
    #ansible-playbook playbooks/ocp4_06_deploy_webserver.yml
    ansible-playbook playbooks/ocp4_05_create_ignition_configs.yml
    NODE_NETINFO=$(mktemp)
    sudo virsh net-dumpxml ocp42 | grep 'host mac' > $NODE_NETINFO
    deploy_bootstrap_node
    deploy_master_nodes
    deploy_compute_nodes
    start_ocp4_deployment
}
