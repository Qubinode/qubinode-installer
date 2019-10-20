#!/bin/bash
project_dir_path=$(sudo find / -type d -name qubinode-installer)
project_dir=$project_dir_path
echo ${project_dir}
project_dir="`( cd \"$project_dir_path\" && pwd )`"


domain=$(awk '/^domain:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
ssh_username=$(awk '/^admin_user:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
ocp_user=$(awk '/^openshift_user:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
product_name=$(awk '/^product:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
instance_prefix=$(awk '/instance_prefix:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
product_hostname="${instance_prefix}-${product_name}"

infracount=$(cat "${project_dir}/inventory/hosts" | grep $product_hostname-infra | awk '{print $1}')
fdqn_all_node_names="";
infra_names="";
node_names="";
for item in $infracount; do
  echo $item.$domain
  fdqn_all_node_names+="'$item.$domain',"
  infra_names+="'$item.$domain',"
  node_names+="'$item',"
done

nodecount=$(cat "${project_dir}/inventory/hosts" | grep $product_hostname-node | awk '{print $1}')
fdqn_node_names="";
for item in $nodecount; do
  echo $item.$domain
  fdqn_all_node_names+="'$item.$domain',"
  fdqn_node_names+="'$item.$domain',"
  node_names+="'$item',"
  compute_node_names+="'$item',"
done

fdqn_all_node_names=$(echo $fdqn_all_node_names | sed 's/,*$//g')
echo $fdqn_all_node_names
fdqn_node_names=$(echo $fdqn_node_names | sed 's/,*$//g')
echo $fdqn_node_names
infra_names=$(echo $infra_names | sed 's/,*$//g')
echo $infra_names
node_names=$(echo $node_names | sed 's/,*$//g')
echo $node_names
compute_node_names=$(echo $compute_node_names | sed 's/,*$//g')
echo $compute_node_names


cat >/tmp/cluster-inventory<<EOF
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

cat >/tmp/ocp-power-management.yml<<EOF
---
- hosts: master
  remote_user: ${ssh_username}
  gather_facts: no
  roles:
    - ocp-power-management
EOF

#ansible-playbook -i /tmp/cluster-inventory /tmp/ocp-power-management.yml || exit 1

ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${product_hostname}-master01.$domain "shutdown 'Shutting Down Node'"
sudo virsh shutdown "${product_hostname}-master01"
# Wait until all domains are shut down or timeout has reached.
END_TIME=$(date -d "$TIMEOUT seconds" +%s)
while [ $(date +%s) -lt $END_TIME ]; do
    test -z "$(sudo virsh list | grep master01)" && break
    sleep 1
done

rm /tmp/ocp-power-management.yml
rm /tmp/cluster-inventory

exit 0
