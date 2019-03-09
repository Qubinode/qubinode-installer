#!/bin/bash
set -x

if [[ -z $1 ]]; then
  echo "Please pass inventory file."
  echo "Usage: delete_openshift_deployment.sh inventory.openshift"
  echo "To skip menu and delete all machines run the command below."
  echo "Usage: delete_openshift_deployment.sh inventory.openshift DELLALL"
  exit 1
fi

function dellall() {
  sudo ansible-playbook -i  $1 tasks/delete_kvm.yml  --extra-vars "machine=jumpbox"
  sudo ansible-playbook -i  $1 tasks/delete_kvm.yml  --extra-vars "machine=master"
  sudo ansible-playbook -i  $1 tasks/delete_kvm.yml  --extra-vars "machine=nodes"
  sudo ansible-playbook -i  $1 tasks/delete_kvm.yml  --extra-vars "machine=lb"
  rm -rf jumpbox master node1 node2 node3 lb hosts
}

function selectone() {
  PS3='Please enter your choice: '
  options=("jumpbox" "master" "nodes" "lb" "quit")
  select opt in "${options[@]}"
  do
    case $opt in
        "jumpbox")
            sudo ansible-playbook -i  $1 tasks/delete_kvm.yml  --extra-vars "machine=jumpbox"
            rm jumpbox
            echo "Type 5 to exit."
            ;;
        "master")
            sudo ansible-playbook -i  $1 tasks/delete_kvm.yml  --extra-vars "machine=master"
            rm master
            echo "Type 5 to exit."
            ;;
        "nodes")
            sudo ansible-playbook -i  $1 tasks/delete_kvm.yml  --extra-vars "machine=nodes"
            rm node1 node2 node3
            echo "Type 5 to exit."
            ;;
        "lb")
            sudo ansible-playbook -i  $1 tasks/delete_kvm.yml  --extra-vars "machine=lb"
            rm lb
            echo "Type 5 to exit."
            ;;
        "quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
  done
}
if [[ -f $1 ]] && [[ "DELLALL" = $2 ]]; then
   dellall $1
elif [[ -f $1 ]]; then
  while true; do
    read -p "Do you want to delete all vms? " yn
    case $yn in
        [Yy]* ) dellall $1; break;;
        [Nn]* ) selectone $1; break;;
        * ) exit 0;;
    esac
  done
else
  echo "$1 Not Found!"
  exit 1
fi
