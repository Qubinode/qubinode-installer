#!/bin/bash
# Author: Tosin Akinosho
# Openshift-home-lab bootstrap script

echo "Generating inventory file for dns server."
read -p "Enter Domain Name default is example.com: " DOMAINNAME
read -p "Enter Red Hat Subscription username: " RHEL_USERNAME
read -s -p "Enter Red Hat Subscription password : " RHEL_PASSWORD
echo
read -p "Enter username to login to node " SSH_USERNAME
read -s -p "Enter password to login to node  : " SSH_PASSWORD
echo

if [[ -z ${DOMAINNAME} ]]; then
  DOMAINNAME="example.com"
fi

RHEL_IMAGE=$(ls /kvm/kvmdata/rhel-server-7.6-x86_64-kvm.qcow2  2>/dev/null)
if [[ -z $RHEL_IMAGE ]]; then
  cp /opt/kvmimage/rhel-server-7.6-x86_64-kvm.qcow2 /kvm/kvmdata/
fi

bash scripts/generate_dns_server_inventory.sh ${DOMAINNAME} ${RHEL_USERNAME} ${RHEL_PASSWORD} ${SSH_USERNAME} ${SSH_PASSWORD}

./dns_server/deploy_dns_server.sh rhel inventory.dnsserver $SSH_USERNAME

# Deply dns sever and get ip

#bash scripts/generate_dns_server_inventory.sh ${DOMAINNAME} ${DOMAINIP} ${RHEL_USERNAME} ${RHEL_PASSWORD} ${SSH_USERNAME} ${SSH_PASSWORD}
