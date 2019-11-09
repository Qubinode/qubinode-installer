#!/bin/bash

function config_err_msg () {
    cat << EOH >&2
  There was an error finding the full path to the qubinode-installer project directory.
EOH
}

# this function just make sure the script
# knows the full path to the project directory
# and runs the config_err_msg if it can't determine
# that start_deployment.conf can find the project directory
function setup_required_paths () {
    current_dir="`dirname \"$0\"`"
    project_dir="$(dirname ${current_dir})"
    project_dir="`( cd \"$project_dir\" && pwd )`"
    if [ -z "$project_dir" ] ; then
        config_err_msg; exit 1
    fi

    if [ ! -d "${project_dir}/playbooks/vars" ] ; then
        config_err_msg; exit 1
    fi
}

setup_required_paths
openshift3_variables

infracount=$(cat "${project_dir}/inventory/hosts" | grep $productname-infra | awk '{print $1}')
fdqn_all_node_names="";
infra_names="";
node_names="";
for item in $infracount; do
  echo $item.$domain
  fdqn_all_node_names+="'$item.$domain',"
  fqdn_infra_names+="'$item.$domain',"
  node_names+="'$item',"
  infra_node_names+="'$item',"
done

nodecount=$(cat "${project_dir}/inventory/hosts" | grep $productname-node | awk '{print $1}')
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
fqdn_infra_names=$(echo $fqdn_infra_names | sed 's/,*$//g')
echo $fqdn_infra_names
infra_node_names=$(echo $infra_node_names | sed 's/,*$//g')
echo $infra_node_names
node_names=$(echo $node_names | sed 's/,*$//g')
echo $node_names
compute_node_names=$(echo $compute_node_names | sed 's/,*$//g')
echo $compute_node_names

cat >/tmp/cluster-inventory<<EOF
[master]
${productname}-master01.$domain

[master:vars]
#options for power_state reboot, halt, running
power_state="reboot"
rhel_user="${ssh_username}"
# use for master node endpoint
master_node="${productname}-master01.$domain"
master_name="${productname}-master01"
# FQDN names used for power down and power up tasks
fdqn_node_names=[ $(echo $fdqn_all_node_names) ]
fqdn_infra_names=[ $(echo $fqdn_infra_names) ]
fqdn_compute_names=[ $(echo $fdqn_node_names) ]

# node names used for power up and power down nodes
node_names=[ $(echo $node_names) ]
infra_nodes=[ $(echo $infra_node_names) ]
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

ansible-playbook -i /tmp/cluster-inventory /tmp/ocp-power-management.yml  || exit 1

rm /tmp/ocp-power-management.yml
rm /tmp/cluster-inventory

echo "Run Smoke test on environment."
echo "${project_dir}/qubinode-installer -c smoketest"

exit 0
