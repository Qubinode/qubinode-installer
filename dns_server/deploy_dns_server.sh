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
#/ Edit inventory.dnserver for your enviornment
#/
#########################
# The command line help #
#########################
function display_help() {
    echo "Usage for centos deployment: $0 centos inventory.centos.dnsserver" >&2
    echo "Usage for rhel deployment: $0 rhel inventory.rhel.dnsserver username" >&2
    echo
    # echo some stuff here for the -a or --add-options
    exit 1
}

function collectdnsinfo() {
    read -p "Enter your dns zone name (Example: example.com): " DEFAULTDNSNAME
    read -p "Enter your bind zone networks (Example: 192.168.1): " DNSZONE
}

function collectuserpassword() {
  read -p "Enter RHEL Subscription USERNAME: " RHEL_USERNAME
  echo "Enter RHEL Subscription PASSWORD: "
  unset RHEL_PASSWORD;
  while IFS= read -r -s -n1 pass; do
    if [[ -z $pass ]]; then
       echo
       break
    else
       echo -n '*'
       RHEL_PASSWORD+=$pass
    fi
  done

}

#########################
# The command line help #
#########################
function validation() {
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

function main() {
  # check_args "${@}"
  :
  if [ "$1" == "-h" ] ; then
    display_help
    exit 0
  fi

  if [[ "$1" == "centos" ]] && [[ ! -z "$2" ]] ; then
    FULLPATH=$(pwd)
    validation
    addssh
    $USESUDO ansible-playbook -i $2 $FULLPATH/dns_server/deploy_dns_kvm_centos.yml || exit 1

    DNSFILEPATH=$(ls $(pwd)/dns*  | head -n1)
    echo $DNSFILEPATH
    if [[ -f  $DNSFILEPATH ]]; then
      DNSSERVER=$(cat $DNSFILEPATH | tr -d '"[]",')
cat <<EOF > inventory.vm.dnsserver
[dns_server]
${DNSSERVER}

EOF

lastip=`echo "$DNSSERVER" | sed 's/^.*\.\([^.]*\)$/\1/'`
echo $lastip || exit 1
    else
      exit 1
    fi

    cp $FULLPATH/dns_server/deploy_dns_server.yml  $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml  || exit 1

    scripts/share_keys.sh ${DNSSERVER} centos || exit 1

    collectdnsinfo

    sed -ri 's/^(\s*)(bind_zone_master_server_ip\s*:\s*0.0.0.0\s*$)/\    bind_zone_master_server_ip: '$DNSSERVER'/' $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1
    sed -ri 's/^(\s*)(ip\s*:\s*0.0.0.0\s*$)/\      ip: '$DNSSERVER'/' $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1
    sed -ri 's/^(    - name: example.com)/\    - name: '$DEFAULTDNSNAME'/' $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1
    sed -ri 's/^(\s*)(bind_zone_name\s*:\s*example.com\s*$)/\    bind_zone_name: '$DEFAULTDNSNAME'/' $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1
    sed -ri 's/(      - "0.0.0")/\      - "'$DNSZONE'" /'  $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1

    $USESUDO ansible-playbook -i inventory.vm.dnsserver  $FULLPATH/dns_server/provision_dns_server.yml  --extra-vars="rhel_user=centos"  || exit 1
    $USESUDO ansible-playbook -i inventory.vm.dnsserver  $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml --extra-vars="rhel_user=centos"  || exit 1

    ansible-playbook   -i inventory.vm.dnsserver tasks/restart_vm.yml  --extra-vars="rhel_user=centos"

  elif [[ "$1" == "rhel" ]] && [[ ! -z "$2" ]] && [[ ! -z "$3" ]]; then
    FULLPATH=$(pwd)
    validation
    addssh
    $USESUDO ansible-playbook -i $2 $FULLPATH/dns_server/deploy_dns_kvm_rhel.yml || exit 1

    DNSFILEPATH=$(ls $(pwd)/dns*  | head -n1)
    echo $DNSFILEPATH
    if [[ -f  $DNSFILEPATH ]]; then
      DNSSERVER=$(cat $DNSFILEPATH | tr -d '"[]",')
cat <<EOF > inventory.vm.dnsserver
[dns_server]
${DNSSERVER}

EOF

lastip=`echo "$DNSSERVER" | sed 's/^.*\.\([^.]*\)$/\1/'`
echo $lastip || exit 1
    else
      exit 1
    fi

    cp $FULLPATH/dns_server/deploy_dns_server.yml  $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml  || exit 1

    scripts/share_keys.sh ${DNSSERVER} $3
    collectdnsinfo

    sed -ri 's/^(\s*)(bind_zone_master_server_ip\s*:\s*0.0.0.0\s*$)/\    bind_zone_master_server_ip: '$DNSSERVER'/' $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1
    sed -ri 's/^(\s*)(ip\s*:\s*0.0.0.0\s*$)/\      ip: '$DNSSERVER'/' $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1
    sed -ri 's/^(    - name: example.com)/\    - name: '$DEFAULTDNSNAME'/' $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1
    sed -ri 's/^(\s*)(bind_zone_name\s*:\s*example.com\s*$)/\    bind_zone_name: '$DEFAULTDNSNAME'/' $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1
    sed -ri 's/(      - "0.0.0")/\      - "'$DNSZONE'" /'  $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml || exit 1

    collectuserpassword
    $USESUDO ansible-playbook -i inventory.vm.dnsserver  $FULLPATH/dns_server/provision_dns_server.yml  --extra-vars="rhel_user=$3"    --extra-vars="rhel_username=$RHEL_USERNAME"   --extra-vars="rhel_password=$RHEL_PASSWORD" || exit 1
    $USESUDO ansible-playbook -i inventory.vm.dnsserver  $FULLPATH/dns_server/deploy_dns_server.${lastip}.yml --extra-vars="rhel_user=$3"  || exit 1
    ansible-playbook   -i inventory.vm.dnsserver tasks/restart_vm.yml  --extra-vars="rhel_user=$3"
  else
    display_help
  fi

}

main "${@}"
