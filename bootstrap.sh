#!/bin/bash
# Author: Tosin Akinosho
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

source scripts/bootstrapvaidator.sh


if [[ -f bootstrap_env ]]; then
    running_install_check
    CHECKFOR_DNS=$(virsh list | grep running | grep dnsserver | wc -l)
    if [[ $CHECKFOR_DNS -eq 1 ]] && [[ -f "skipask" ]]; then
      sed -i 's/export CREATE_DNS_KEY=TRUE/export CREATE_DNS_KEY=FALSE/g' bootstrap_env
      source bootstrap_env
      DOMAINNAME=$DEFAULTDNSNAME
    elif [[ $CHECKFOR_DNS -eq 1 ]] && [[ ! -f "skipask" ]]; then
      source bootstrap_env
      DOMAINNAME=$DEFAULTDNSNAME
    else
      askquestions

      bash scripts/generate_dns_server_inventory.sh || exit 1

      ./dns_server/deploy_dns_server.sh rhel inventory.dnsserver  || exit 1
    fi
else

    askquestions
    bash scripts/generate_dns_server_inventory.sh ${DOMAINNAME} ${RHEL_USERNAME} ${RHEL_PASSWORD} ${SSH_USERNAME} ${SSH_PASSWORD} || exit 1

    ./dns_server/deploy_dns_server.sh rhel inventory.dnsserver $SSH_USERNAME || exit 1
fi

DNSSERVERIP=$(cat dnsserver  | tr -d '"[]"')
DNSCHECKINENV=$(cat bootstrap_env | grep $DNSSERVERIP 2>/dev/null)
if [[ -z $DNSCHECKINENV ]]; then
  echo "export DNSSERVERIP=$DNSSERVERIP" >> bootstrap_env
fi

# Deply dns sever and get ip
bash scripts/generate_kvm_inventory.sh  || exit 1


./start_deployment.sh  rhel inventory.rhel.openshift  v3.11.104 || exit 1


JUMPBOX=$(cat jumpbox  | tr -d '"[]"')
read -p "KVM Deployment complete. if you would like to deploy OpenShift now press Y/N? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    ssh tosin@${JUMPBOX} '/home/'${SSH_USERNAME}'/start_openshift_deployment.sh' ${SSH_USERNAME} inventory.3.11.rhel.gluster
else
cat << EOF
  You can deploy OpenShift at any time using the commands below.
  ssh tosin@${JUMPBOX} '/home/${SSH_USERNAME}/start_openshift_deployment.sh' ${SSH_USERNAME} inventory.3.11.rhel.gluster
EOF
fi
#rm bootstrap_env
