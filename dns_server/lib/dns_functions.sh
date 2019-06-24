############################################
# configure_dns_for_arecord functions      #
###########################################
function configure_dns_for_arecord() {
    DNSSERVER=$(cat ${1} | grep dns_servers=* | tr -d '"[]",' | awk '{print $1}' | cut -d'=' -f2)
    DOMAINNAME=$(cat ${1} | grep search_domain| awk '{print $1}' | cut -d'=' -f2)
    #DOMAINPREFIX=$(echo $DOMAINNAME | cut -d'.' -f1)
    lastip=`echo "$DNSSERVER" | sed 's/^.*\.\([^.]*\)$/\1/'`
    oct1=$(echo ${DNSSERVER} | tr "." " " | awk '{ print $1 }')
    oct2=$(echo ${DNSSERVER} | tr "." " " | awk '{ print $2 }')
    oct3=$(echo ${DNSSERVER} | tr "." " " | awk '{ print $3 }')

    echo "Generating dns_server/update_dns_server_${lastip}_entry.yml" || exit 1

    cp  dns_server/update_dns_server_entry.yml  dns_server/update_dns_server_${lastip}_entry.yml  || exit 1
    sed -ri 's/^(\s*)(zone\s*:\s*"example.com"\s*$)/\      zone: "'$DOMAINNAME'"/' dns_server/update_dns_server_${lastip}_entry.yml || exit 1
    sed -ri 's/^(\s*)(server\s*:\s*"0.0.0.0"\s*$)/\      server: "'$DNSSERVER'"/' dns_server/update_dns_server_${lastip}_entry.yml || exit 1

    if [[ -f skipask ]]; then
      source skipask
      sed -ri 's/^(\s*)(key_name\s*:\s*"example.key"\s*$)/\      key_name: "'$KEYNAME'."/' dns_server/update_dns_server_${lastip}_entry.yml || exit 1
    else
      manual_enter_key
    fi

    echo "Verifing DNS Configuration"
    cat dns_server/update_dns_server_${lastip}_entry.yml | grep "${DNSSERVER}"  || exit 1
    echo -e "\e[32mTESTING test.${DOMAINNAME} ${oct1}.${oct2}.${oct3}.250\e[0m"
    sleep 3s
    if [[ -f skipask ]]; then
      source skipask
      ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=test" --extra-vars="ip_address=${oct1}.${oct2}.${oct3}.250" --extra-vars="rhel_user=${2}" --extra-vars="user_data_file=${DNSKEY_PATH}" --vault-password-file=ansible-vault.pass || exit 1
    else
      ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=test" --extra-vars="ip_address=${oct1}.${oct2}.${oct3}.250" --extra-vars="rhel_user=${2}" --extra-vars="user_data_file=" --vault-password-file=ansible-vault.pass || exit 1
    fi
}
################################
# manually enter key function  #
###############################
function manual_enter_key() {
  #statements
  if [[ -z $DNS_KEY_NAME ]]; then
    echo -e "\e[32m************************\e[0m"
    read -p "Enter DNS KEYNAME: " DNS_KEY_NAME
    echo -e "\e[32m************************\e[0m"
  fi

  sed -ri 's/^(\s*)(key_name\s*:\s*"example.key"\s*$)/\      key_name: "'$DNS_KEY_NAME'."/' dns_server/update_dns_server_${lastip}_entry.yml || exit 1

  echo -e "\e[32m************************\e[0m"
  echo -e "\e[32mKey secret for DNS server this will allow script to write a records to your dnsserver: \e[0m"
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
  echo -e "\e[32m*Enter Ansible Vault password: \e[0m"
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

}

##############################
# set_arecord functions      #
##############################
function set_arecord() {
    DOMAINNAME=$(cat ${1}| grep search_domain| awk '{print $1}' | cut -d'=' -f2)
    #DOMAINPREFIX=$(echo $DOMAINNAME | cut -d'.' -f1)

    DNSSERVER=$(cat ${1} | grep dns_servers=* | tr -d '"[]",' | awk '{print $1}' | cut -d'=' -f2)
    lastip=`echo "$DNSSERVER" | sed 's/^.*\.\([^.]*\)$/\1/'`

    JUMPBOXIP=$(cat jumpbox | tr -d '"[]",')
    [ ! -f "skipask" ] && ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=jumpbox" --extra-vars="ip_address=${JUMPBOXIP}" --extra-vars="rhel_user=${2}"  --extra-vars="user_data_file=" --vault-password-file=ansible-vault.pass || exit 1
    [ -f "skipask" ] && source skipask;ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=jumpbox" --extra-vars="ip_address=${JUMPBOXIP}" --extra-vars="rhel_user=${2}"  --extra-vars="user_data_file=${DNSKEY_PATH}" --vault-password-file=ansible-vault.pass || exit 1
    sleep 2s
    dig +short jumpbox.${DOMAINNAME} @${DNSSERVER} | grep ${JUMPBOXIP} || exit 1
    MASTERIP=$(cat master | tr -d '"[]",')
    [ ! -f "skipask" ] && ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=master" --extra-vars="ip_address=${MASTERIP}" --extra-vars="rhel_user=${2}"  --extra-vars="user_data_file=" --vault-password-file=ansible-vault.pass || exit 1
    [ -f "skipask" ] && source skipask;ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=master" --extra-vars="ip_address=${MASTERIP}" --extra-vars="rhel_user=${2}"  --extra-vars="user_data_file=${DNSKEY_PATH}" --vault-password-file=ansible-vault.pass || exit 1
    sleep 2s
    dig +short master.${DOMAINNAME} @${DNSSERVER} | grep ${MASTERIP} || exit 1

    NODES=$(ls node*)

    for n in $NODES; do
      NODEIP=$(cat $n | tr -d '"[]",')
      [ ! -f "skipask" ] && ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=${n}" --extra-vars="ip_address=${NODEIP}" --extra-vars="rhel_user=${2}" --extra-vars="user_data_file=" --vault-password-file=ansible-vault.pass || exit 1
      [ -f "skipask" ] && source skipask;ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=${n}" --extra-vars="ip_address=${NODEIP}" --extra-vars="rhel_user=${2}"  --extra-vars="user_data_file=${DNSKEY_PATH}" --vault-password-file=ansible-vault.pass || exit 1
      INFRANODE=$(cat ${3} | grep node-config-infra | tr   = " " | awk '{print $1}')
      dig +short ${n}.${DOMAINNAME} @${DNSSERVER} | grep ${NODEIP}|| exit 1
      if [[ $n ==  $INFRANODE ]]; then
        APPENDPOINT=$(cat ${3} | grep openshift_master_default_subdomain= | tr   = " " | awk '{print $2}' | tr . " "| awk '{print $1}')
        [ ! -f "skipask" ] && ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=*.${APPENDPOINT}" --extra-vars="ip_address=${NODEIP}" --extra-vars="rhel_user=${2}"  --extra-vars="user_data_file=" --vault-password-file=ansible-vault.pass || exit 1
        [ -f "skipask" ] && source skipask;ansible-playbook -i inventory.vm.dnsserver dns_server/update_dns_server_${lastip}_entry.yml  --extra-vars="a_record=*.${APPENDPOINT}" --extra-vars="ip_address=${NODEIP}" --extra-vars="rhel_user=${2}"  --extra-vars="user_data_file=${DNSKEY_PATH}" --vault-password-file=ansible-vault.pass || exit 1
        dig +short test.${DOMAINNAME} @${DNSSERVER} | grep ${NODEIP} || exit 1
      fi
    done

    echo "cleanup enviornment "
    cleanup
}

#########################
# cleanup functions     #
#########################
function cleanup() {
  if [[ -f   ansible-vault.pass ]]; then
    read -p "Would you like to remove ansible-vault.pass file? `echo $'\n\e[31mYou will not be able to use the update_dns_server_${lastip}_entry.yml if you do:\e[0m '` " -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        rm  ansible-vault.pass
    fi
  fi

  [ -f "skipask" ] && rm skipask
}
##########################################
# configurednsforopenshift functions     #
##########################################
function configurednsforopenshift() {
  DNS_ZONE=$(cat ${1} | grep search_domain| awk '{print $1}' | cut -d'=' -f2)
  DOMAINNAME=$(echo $DNS_ZONE | cut -d'.' -f2)

  DNSSERVER=$(cat ${1} | grep dns_servers=* | tr -d '"[]",' | awk '{print $1}' | cut -d'=' -f2)

  if [[ ! -f inventory.vm.dnsserver ]]; then
cat <<EOF > inventory.vm.dnsserver
[dns_server]
${DNSSERVER}

EOF
fi

  CHECK_DNS=$(cat inventory.vm.dnsserver | grep $DNSSERVER)
  if [[ -z $CHECK_DNS ]]; then
    echo -e "\e[31mDouble check inventory.vm.dnsserver and ${1} files current dns server ip is incorrect \e[0m"
    exit 1
  fi

  echo -e "\e[32m************************\e[0m"
  echo -e "\e[32mChecking if dns server is online.\e[0m"
  echo -e "\e[32m************************\e[0m"
  sleep 3s
  ansible-playbook -i inventory.vm.dnsserver dns_server/port_verification.yml   --extra-vars="port_num=53" --extra-vars="rhel_user=${2}" || exit 1

  if [[ $CREATE_DNS_KEY == "TRUE" ]]; then
    REPLY=y
  elif [[ $CREATE_DNS_KEY == "FALSE" ]];then
    REPLY=n
  else
    read -p "Do you need a dns server secret key  created? " -n 1 -r
  fi


  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo -e "\e[32m************************\e[0m"
    if [[ -z $DNS_KEY_NAME ]]; then
      read -p "Enter Key Name that Ansible will use to write to dns server: " DNS_KEY_NAME
    fi

    echo -e "\e[32m************************\e[0m"
    ansible-playbook -i inventory.vm.dnsserver dns_server/configure_dns_server_for_openshift.yml  --extra-vars="zone_name=${DNS_ZONE}" --extra-vars="key_name=${DNS_KEY_NAME}" --extra-vars="dns_server_ip=${DNS_IP}"  --extra-vars="rhel_user=$2" --extra-vars="domain_name=${DOMAINNAME}.com" --extra-vars="server_ip=$(hostname --ip-address | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | head -1)"|| exit 1
cat <<EOF > skipask
KEYNAME=${DNS_KEY_NAME}
DNSKEY_PATH=/etc/named/${DNS_KEY_NAME}.
EOF
  fi

}
