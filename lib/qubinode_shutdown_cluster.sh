#!/bin/bash


function openshift3_cluster_shutdown_temp_inventory () {
    # load variables
    fdqn_all_node_names=""
    infra_names=""
    node_names=""
    fdqn_node_names="";
    product_hostname="${productname}"
    cluster_inventory="${hosts_inventory_dir}/openshift3_cluster_shutdown"
    cluster_shutdown_playbook="${playbooks_dir}/openshift3_cluster_shutdown.yml"

    infracount=$(cat "${inventory_file}" | grep ${product_hostname}-infra | awk '{print $1}')
    for item in $infracount; do
        fdqn_all_node_names+="'$item.$domain',"
        infra_names+="'$item.$domain',"
        node_names+="'$item',"
    done

    nodecount=$(cat "${inventory_file}" | grep $product_hostname-node | awk '{print $1}')
    for item in $nodecount; do
        fdqn_all_node_names+="'$item.$domain',"
        fdqn_node_names+="'$item.$domain',"
        node_names+="'$item',"
        compute_node_names+="'$item',"
    done

    #fdqn_all_node_names=$(echo $fdqn_all_node_names | sed 's/,*$//g')
    #echo $fdqn_all_node_names
    #fdqn_node_names=$(echo $fdqn_node_names | sed 's/,*$//g')
    #echo $fdqn_node_names
    #infra_names=$(echo $infra_names | sed 's/,*$//g')
    #echo $infra_names
    #node_names=$(echo $node_names | sed 's/,*$//g')
    #echo $node_names
    #compute_node_names=$(echo $compute_node_names | sed 's/,*$//g')
    #echo $compute_node_names


cat >"${cluster_inventory}"<<EOF
[master]
${product_hostname}-master01.$domain
[master:vars]
#options for power_state reboot, halt, running
power_state="halt"
rhel_user="${ssh_username}"
# use for master node endpoint
master_node="${product_hostname}-master01.$domain"
# FQDN names used for power down and power up tasks
fdqn_node_names=[ $(echo $fdqn_all_node_names) ]
fqdn_compute_names=[ $(echo $fdqn_node_names) ]
# node names used for power up and power down nodes
node_names=[ $(echo $node_names) ]
infra_nodes=[ $(echo $infra_names) ]
compute_nodes=[ $(echo $compute_node_names) ]
EOF

cat >"${cluster_shutdown_playbook}"<<EOF
---
- hosts: master
  remote_user: ${ssh_username}
  gather_facts: no
  roles:
    - ocp-power-management
EOF

}

function wait_for_nodes_shutdown () {
    while sudo virsh list|grep -qE 'node|infra'
    do
        echo "Waiting on nodes to shutdown..."
        sleep 1
    done
    echo "The infra and app nodes are shutoff"
}

function openshift3_shutdown_master () {
    MASTER_NODE="$1"
    MASTER_FQDN="$2"
    SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    if sudo virsh list|grep -qE "${MASTER_NODE}"
    then
        ssh "${SSH_ARGS}" "${MASTER_FQDN}" "shutdown 'Shutting Down Node'"
        sudo virsh shutdown "${MASTER_NODE}"
    fi
    while sudo virsh list|grep -qE "${MASTER_NODE}"
    do
        echo "Waiting on "${MASTER_NODE}" node to shutdown..."
        sleep 1
    done
    echo "The master node ${MASTER_NODE} is shutoff"
}

function openshift3_cluster_shutdown () {
    TIMEOUT_ARGS="--preserve-status 300s"
    if sudo virsh list|grep -qE 'node|infra'
    then
        openshift3_cluster_shutdown_temp_inventory 
        echo "Shutting down nodes: ${fdqn_all_node_names}"
        ansible-playbook -i "${cluster_inventory}" "${cluster_shutdown_playbook}" || exit 1
    fi
    nodes_msg="Timeout threshold reached: nodes did not shutdown"
    export -f wait_for_nodes_shutdown
    timeout $TIMEOUT_ARGS bash -c wait_for_nodes_shutdown
    if [ $? -eq 124 ]
    then
        echo "$nodes_msg"
        exit 1
    fi
   
    # Shutdown master 
    master_msg="Timeout threshold reached: $master_node did not shutdown"
    export -f openshift3_shutdown_master
    timeout $TIMEOUT_ARGS bash -c "openshift3_shutdown_master $productname ${productname}.${domain}"
    if [ $? -eq 124 ]
    then
        echo "$master_msg"
        exit 1
    fi
}
