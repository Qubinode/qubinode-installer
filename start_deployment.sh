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
# The command line help #
#########################
function display_help() {
    echo "Usage: $0 [option...] {start|stop|restart}" >&2
    echo
    echo "Usage for centos deployment: $0 centos inventory.centos.openshift  inventory.3.11.centos.gluster" >&2
    echo "Usage for rhel deployment: $0 rhel inventory.rhel.openshift  inventory.3.11.rhel.gluster" >&2
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

function addgluster() {
  RESULT=$(grep -A12 '\[nodes:vars\]'  $1 | grep glusterstorage=true)
  MASTERRESULT=$(grep -A12 '\[master:vars\]'  $1 | grep glusterstorage=true)
  if [[ ! $(grep glusterstorage=true  inventory.vm.provision) ]]; then
    if [[ ! -z  "${RESULT}" ]] && [[ ! -z  "${MASTERRESULT}" ]] ; then
      echo "[nodes:vars] glusterstorage=true"
      echo "[master:vars] glusterstorage=true"
      echo "[OSEv3:vars]" >> inventory.vm.provision
      echo "glusterstorage=true" >> inventory.vm.provision
    elif [[ ! -z  "${RESULT}" ]] ; then
      echo "[nodes:vars] glusterstorage=true"
    elif [[ ! -z  "${MASTERRESULT}" ]]; then
      echo "[master:vars] glusterstorage=true"
    fi
  fi
}

function configure_dns_for_arecord() {
    DNSSERVER=$(cat ${1} | grep dns_servers=* | tr -d '"[]",' | awk '{print $1}' | cut -d'=' -f2)
    DOMAINNAME=$(cat ${1} | grep search_domain| awk '{print $1}' | cut -d'=' -f2)
    lastip=`echo "$DNSSERVER" | sed 's/^.*\.\([^.]*\)$/\1/'`
    echo "Generating dns_server/update_dns_server_${lastip}_entry.yml" || exit 1

    cp  dns_server/update_dns_server_entry.yml  dns_server/update_dns_server_${lastip}_entry.yml  || exit 1
    sed -ri 's/^(\s*)(zone\s*:\s*"example.com."\s*$)/\      zone: "'$DOMAINNAME'."/' dns_server/update_dns_server_${lastip}_entry.yml || exit 1
    sed -ri 's/^(\s*)(server\s*:\s*"0.0.0.0"\s*$)/\      server: "'$DNSSERVER'"/' dns_server/update_dns_server_${lastip}_entry.yml || exit 1

    echo -e "\e[32m************************\e[0m"
    read -p "\e[32m*-0 : \e[0m" DNS_KEY_NAME
    echo -e "\e[32m************************\e[0m"
    sed -ri 's/^(\s*)(key_name\s*:\s*"example.key"\s*$)/\      key_name: "'$DNS_KEY_NAME'."/' dns_server/update_dns_server_${lastip}_entry.yml || exit 1

    echo -e "\e[32m************************\e[0m"
    echo "\e[32m*Key Secert for DNS server this will allow script to write a records to your dnsserver: \e[0m"
    echo -e "\e[32m************************\e[0m"
    unset SECERT_KEY;
    while IFS= read -r -s -n1 key; do
      if [[ -z $key ]]; then
         echo
         break
      else
         echo -n '*'
         SECERT_KEY+=$key
      fi
    done
#echo "${SECERT_KEY}" > dns_server/dns_key/dns_key
cat <<YAML > dns_server/dns_key/dns_key
---
vault_dns_key: ${SECERT_KEY}

YAML

  echo -e "\e[32m************************\e[0m"
  echo "\e[32m*Enter Ansible Vault password: \e[0m"
  echo -e "\e[32m************************\e[0m"
  unset SECERT_KEY;
  while IFS= read -r -s -n1 key; do
    if [[ -z $key ]]; then
       echo
       break
    else
       echo -n '*'
       SECERT_KEY+=$key
    fi
  done
    echo "${SECERT_KEY}" >   ansible-vault.pass

    ansible-vault encrypt dns_server/dns_key/dns_key   --vault-password-file=ansible-vault.pass

    echo "Verifing DNS Configuration"
    cat dns_server/update_dns_server_${lastip}_entry.yml | grep "${DNSSERVER}"  || exit 1
    cat dns_server/update_dns_server_${lastip}_entry.yml
    read -n 1 -s -r -p "Press any key to continue"
}

function set_arecord() {
    DOMAINNAME=$(cat ${1}| grep search_domain| awk '{print $1}' | cut -d'=' -f2)
    DOMAINPREFIX=$(echo $DOMAINNAME | cut -d'.' -f1)

    DNSSERVER=$(cat ${1} | grep dns_servers=* | tr -d '"[]",' | awk '{print $1}' | cut -d'=' -f2)
    lastip=`echo "$DNSSERVER" | sed 's/^.*\.\([^.]*\)$/\1/'`

    JUMPBOXIP=$(cat jumpbox | tr -d '"[]",')
    ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=jumpbox.${DOMAINPREFIX}" --extra-vars="ip_address=${JUMPBOXIP}" --extra-vars="rhel_user=${2}" --vault-password-file=ansible-vault.pass || exit 1
    MASTERIP=$(cat master | tr -d '"[]",')
    ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=master.${DOMAINPREFIX}" --extra-vars="ip_address=${MASTERIP}" --extra-vars="rhel_user=${2}" --vault-password-file=ansible-vault.pass || exit 1

    NODES=$(ls node*)

    for n in $NODES; do
      NODEIP=$(cat $n | tr -d '"[]",')
      ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=${n}.${DOMAINPREFIX}" --extra-vars="ip_address=${NODEIP}" --extra-vars="rhel_user=${2}" --vault-password-file=ansible-vault.pass || exit 1
      INFRANODE=$(cat inventory.3.11.centos.gluster | grep node-config-infra | tr   = " " | awk '{print $1}')
      if [[ $n ==  $INFRANODE ]]; then
        APPENDPOINT=$(cat inventory.3.11.centos.gluster | grep openshift_master_default_subdomain= | tr   = " " | awk '{print $2}')
        ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=*.${APPENDPOINT}" --extra-vars="ip_address=${NODEIP}" --extra-vars="rhel_user=${2}" --vault-password-file=ansible-vault.pass || exit 1
      fi
    done


  rm  ansible-vault.pass

}

function configurednsforopenshift() {
  read -p "Do you need a dns server secret key  created? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    if [[ ! -f inventory.vm.dnsserver ]]; then
      read -p "Enter DNS IP address: " DNS_IP
cat <<EOF > inventory.vm.dnsserver
[dns_server]
${DNS_IP}

EOF
    fi

    DNS_ZONE=$(cat ${1} | grep search_domain| awk '{print $1}' | cut -d'=' -f2)
    DOMAINNAME=$(echo $DNS_ZONE | cut -d'.' -f2)
    echo -e "\e[32m************************\e[0m"
    read -p "\e[32mEnter Key Name that Ansible will use to write to dns server: \e[0m" DNS_KEY
    echo -e "\e[32m************************\e[0m"
    ansible-playbook -i inventory.vm.dnsserver dns_server/configure_dns_server_for_openshift.yml  --extra-vars="zone_name=${DNS_ZONE}" --extra-vars="key_name=${DNS_KEY}" --extra-vars="dns_server_ip=${DNS_IP}"  --extra-vars="rhel_user=$2" --extra-vars="domain_name=${DOMAINNAME}.com"
  fi
}

main() {
    # check_args "${@}"
    :
    if [ "$1" == "-h" ] ; then
      display_help
      exit 0
    fi

    if [[ "$1" == "centos" ]] && [[ -f "$2"  ]] && [[ -f "$3"  ]]; then
      validation $2
      addssh
      configurednsforopenshift $2 centos

      configure_dns_for_arecord $2
      echo -e "\e[32m************************\e[0m"
      echo -e "\e[32mDeploying Openshift vms\e[0m"
      echo -e "\e[32m************************\e[0m"
      $USESUDO ansible-playbook  -i $2 deploy_openshift_vms_centos.yml --become || exit 1
      echo -e "\e[32m************************\e[0m"
      echo -e "\e[32mCreating inventory files from newly created vms\e[0m"
      echo -e "\e[32m************************\e[0m"
      bash scripts/provision_openshift_nodes.sh || exit 1
      ansible-playbook -i $2  tasks/hosts_generator.yml || exit 1

      ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=jumpboxdeploy" --extra-vars="rhel_user=centos" || exit 1

      ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=OSEv3" --extra-vars="rhel_user=centos" || exit 1

      JUMPBOX=$(cat jumpbox | tr -d '"[]",')
      echo "Generating ssh key on ${JUMPBOX}"
      scripts/generation_jumpbox_ssh_key.sh  centos ${JUMPBOX}
      sharekey centos

      addgluster $2

      ansible-playbook -i inventory.vm.provision tasks/openshift_jumpbox-v3.11.yml  --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=centos" || exit 1

      ansible-playbook -i inventory.vm.provision tasks/configure_docker_regisitry.yml --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=centos" --become || exit 1

      ansible-playbook -i inventory.vm.provision tasks/openshift_nodes-v3.11.yml   --extra-vars "rhel_user=centos" || exit 1

      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ssh-add-script.sh  centos@${JUMPBOX}:~/openshift-ansible

      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $3  centos@${JUMPBOX}:~/openshift-ansible

      set_arecord $2 centos
    elif [[ "$1" == "rhel" ]]  && [[ -f "$2"  ]] && [[ -f "$3"  ]]; then
      read -p "Enter USERNAME for vm login: " RHEL_USER
      validation $2
      addssh
      configurednsforopenshift $2 ${RHEL_USER}
      configure_dns_for_arecord $2
      echo -e "\e[32mDeploying Openshift vms\e[0m"
      $USESUDO  ansible-playbook -i $2 deploy_openshift_vms.yml  --become  || exit 1
      echo -e "\e[32mCreating inventory files from newly created vms\e[0m"
      bash scripts/provision_openshift_nodes.sh || exit 1
      ansible-playbook -i $2  tasks/hosts_generator.yml || exit 1

      ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=jumpboxdeploy" --extra-vars="rhel_user=${RHEL_USER}" || exit 1

      ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=OSEv3" --extra-vars="rhel_user=${RHEL_USER}" || exit 1

      JUMPBOX=$(cat jumpbox | tr -d '"[]",')
      echo "Generating ssh key on ${JUMPBOX}"
      scripts/generation_jumpbox_ssh_key.sh  ${RHEL_USER} ${JUMPBOX}
      sharekey ${RHEL_USER}

      addgluster $2

      ansible-playbook -i inventory.vm.provision tasks/openshift_jumpbox-v3.11.yml  --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=${RHEL_USER}" || exit 1

      ansible-playbook -i inventory.vm.provision tasks/configure_docker_regisitry.yml --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=${RHEL_USER}" --become || exit 1

      ansible-playbook -i inventory.vm.provision tasks/openshift_nodes-v3.11.yml   --extra-vars "rhel_user=${RHEL_USER}" || exit 1

      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ssh-add-script.sh  ${RHEL_USER}@${JUMPBOX}:~/openshift-ansible

      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $3  ${RHEL_USER}@${JUMPBOX}:~/openshift-ansible

      set_arecord $2 ${RHEL_USER}
    else
      display_help
    fi
}

main "${@}"
