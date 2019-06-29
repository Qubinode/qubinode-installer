#!/usr/bin/env bash
# This script will start the automated depoyment of openshift home lab
#
#/ Usage: start_deployment [OPTIONS]... [ARGUMENTS]...
#/
#/
#/ OPTIONS
#/   -h, --help
#/                Print this help message
#/
#/ EXAMPLES
#/
#########################
# import functions      #
#########################
source dns_server/lib/dns_functions.sh
#########################
# The command line help #
#########################
function display_help() {
    echo
    echo "Usage for centos deployment: $0 centos inventory.centos.openshift  v3.11.98" >&2
    echo "Usage for rhel deployment: $0 rhel inventory.rhel.openshift  v3.11.98" >&2
    echo
    # echo some stuff here for the -a or --add-options
    exit 1
}

#########################
# The command line help #
#########################
function validation() {

  DOMAINNAME=$(cat $1 | grep search_domain| awk '{print $1}' | cut -d'=' -f2)
  if [[ -z $DOMAINNAME ]]; then
    echo "Please enter fill out search domain in $1"
    exit 1
  fi

  echo -e "\e[32mChecking if user is root.\e[0m"
  #Check if user is root
  if [[ $EUID -ne 0 ]]; then
   USESUDO="sudo -E "
  fi
}

#########################
# The command line help #
#########################
function addssh() {
  echo -e "\e[32mAdding ssh-key into enviornment.\e[0m"
  source ssh-add-script.sh
}

function sharekey() {

  if [[ -f jumpbox ]]; then
    JUMPBOXIP=$(cat jumpbox | tr -d '"[]",')
    scripts/share_keys.sh ${JUMPBOXIP} ${1}
  fi

  if [[ -f master ]]; then
    MASTERIP=$(cat master | tr -d '"[]",')
    scripts/share_keys.sh ${MASTERIP} ${1}
  fi

  NODES=$(ls node*)

  for n in $NODES; do
    NODEIP=$(cat $n | tr -d '"[]",')
    scripts/share_keys.sh ${NODEIP} ${1}
  done

  if [[ -f lb* ]]; then
    NODES=$(ls lb*)
    for n in $NODES; do
      NODEIP=$(cat $n | tr -d '"[]",')
      scripts/share_keys.sh ${NODEIP} ${1}
    done
  fi
}

function env_check() {
  if [[ -f bootstrap_env ]]; then
    source bootstrap_env
  fi
}

main() {
    # check_args "${@}"dns_servers
    :
    if [ "$1" == "-h" ] ; then
      display_help
      exit 0
    fi

    if [[ "$1" == "centos" ]] && [[ -f "$2"  ]] && [[ ! -z "$3"  ]]; then
      env_check
      validation $2
      addssh
      configurednsforopenshift $2 centos

      configure_dns_for_arecord $2 centos
      echo -e "\e[32m************************\e[0m"
      echo -e "\e[32mDeploying Openshift vms\e[0m"
      echo -e "\e[32m************************\e[0m"
      $USESUDO ansible-playbook  -i $2 deploy_openshift_vms_centos.yml --become || exit 1
      echo -e "\e[32m************************\e[0m"
      echo -e "\e[32mCreating inventory files from newly created vms\e[0m"
      echo -e "\e[32m************************\e[0m"
      bash scripts/provision_openshift_nodes.sh $2 || exit 1
      ansible-playbook -i $2  tasks/hosts_generator.yml || exit 1

      ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=jumpboxdeploy" --extra-vars="rhel_user=centos" || exit 1

      ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=OSEv3" --extra-vars="rhel_user=centos" || exit 1

      JUMPBOX=$(cat jumpbox | tr -d '"[]",')
      echo "Generating ssh key on ${JUMPBOX}"
      scripts/generation_jumpbox_ssh_key.sh  centos ${JUMPBOX}
      sharekey centos

      bash scripts/generate_openshift_inventory.sh $3 centos || exit 1

      set_arecord $2 centos inventory.3.11.${1}.gluster

      addgluster $2

      ansible-playbook -i inventory.vm.provision tasks/openshift_jumpbox-v3.11.yml  --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=centos" || exit 1

      ansible-playbook -i inventory.vm.provision tasks/configure_docker_regisitry.yml --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=centos" --become || exit 1

      ansible-playbook -i inventory.vm.provision tasks/openshift_nodes-v3.11.yml   --extra-vars "rhel_user=centos" || exit 1

      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ssh-add-script.sh  centos@${JUMPBOX}:~/openshift-ansible

      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no inventory.3.11.${1}.gluster  centos@${JUMPBOX}:~/openshift-ansible

    elif [[ "$1" == "rhel" ]]  && [[ -f "$2"  ]] && [[ ! -z "$3"  ]]; then

      env_check

      if [[ -z $SSH_USERNAME ]]; then
        read -p "Enter USERNAME for vm login: " RHEL_USER
      else
        RHEL_USER=${SSH_USERNAME}
      fi

      validation $2
      addssh
      configurednsforopenshift $2 ${RHEL_USER}
      configure_dns_for_arecord $2 ${RHEL_USER}
      echo -e "\e[32mDeploying Openshift vms\e[0m"
      $USESUDO  ansible-playbook -i $2 deploy_openshift_vms.yml  --become  || exit 1
      echo -e "\e[32mCreating inventory files from newly created vms\e[0m"
      bash scripts/provision_openshift_nodes.sh $2 || exit 1
      ansible-playbook -i $2  tasks/hosts_generator.yml || exit 1

      ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=jumpboxdeploy" --extra-vars="rhel_user=${RHEL_USER}" || exit 1

      ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=OSEv3" --extra-vars="rhel_user=${RHEL_USER}" || exit 1

      JUMPBOX=$(cat jumpbox | tr -d '"[]",')
      echo "Generating ssh key on ${JUMPBOX}"
      scripts/generation_jumpbox_ssh_key.sh  ${RHEL_USER} ${JUMPBOX}
      sharekey ${RHEL_USER}

      bash scripts/generate_openshift_inventory.sh $3 rhel || exit 1

      set_arecord $2 ${RHEL_USER} inventory.3.11.${1}.gluster

      addgluster $2

      ansible-playbook -i inventory.vm.provision     tasks/openshift_jumpbox-v3.11.yml  --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=${RHEL_USER}"  --extra-vars="rhel_username=$RHEL_USERNAME"   --extra-vars="rhel_password=$RHEL_PASSWORD" || exit 1

      ansible-playbook -i inventory.vm.provision tasks/configure_docker_regisitry.yml --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=${RHEL_USER}" --become || exit 1

      ansible-playbook -i inventory.vm.provision tasks/openshift_nodes-v3.11.yml   --extra-vars "rhel_user=${RHEL_USER}"  --extra-vars="rhel_username=$RHEL_USERNAME"   --extra-vars="rhel_password=$RHEL_PASSWORD" || exit 1

      ansible-playbook -i inventory.vm.provision tasks/openshift_gluster_config.yml  --extra-vars "rhel_user=${RHEL_USER}"   || exit 1

      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ssh-add-script.sh  ${RHEL_USER}@${JUMPBOX}:~/openshift-ansible

      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no inventory.3.11.${1}.gluster  ${RHEL_USER}@${JUMPBOX}:~/openshift-ansible

      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no start_openshift_deployment.sh ${RHEL_USER}@${JUMPBOX}:~
    else
      display_help
    fi
}

main "${@}"
