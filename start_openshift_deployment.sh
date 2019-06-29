#!/bin/bash

if [[ -z $1 ]] && [[ -z $2 ]]; then
  echo "Please pass username and inventory file to script."
  echo "Usage $0 username inventory.file"
  exit 1
fi

function quickstart() {
  USER=$1
  INVENTORY_FILE=$2
  cd openshift-ansible/
  source ssh-add-script.sh
  if [[ ! -f passwordFile ]]; then
    htpasswd -c passwordFile $USER || exit 1
  fi
  ansible-playbook -i $INVENTORY_FILE  playbooks/prerequisites.yml || exit 1
  ansible-playbook -i $INVENTORY_FILE  playbooks/deploy_cluster.yml || exit 1
}

echo "***********************************************"
echo "*  Starting OpenShift Deployment from jumpbox *"
echo "***********************************************"
quickstart $1 $2
