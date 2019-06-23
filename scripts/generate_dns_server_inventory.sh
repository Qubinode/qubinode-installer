#!/bin/bash
#Author: Tosin Akinosho
# Script used to generate dns  for ansible playbooks
if [ "$#" -ne 5 ]; then
  echo "Please pass the required information."
  echo "Example: $0 example.com rhel-subscription-username rhel-subscription-password ssh-username ssh-password"
  exit 1
fi

DOMAINNAME=$1
CLOUDIMAGE="rhel-server-7.6-x86_64-kvm.qcow2"
RHEL_USERNAME=$2
RHEL_PASSWORD=$3
SSH_USERNAME=$4
SSH_PASSWORD=$5

cat > inventory.dnsserver <<EOF
[dns_server]
dnsserver vm_name=dnsserver vm_local_hostname=dnsserver.${DOMAINNAME} vm_hostname=dnsserver.${DOMAINNAME} vm_data_dir="/kvm/kvmimages/dnsserver_machine" cloud_init_user_data="/kvm/kvmimages/dnsserver_machine/user-data"  cloud_init_meta_data="/kvm/kvmimages/dnsserver_machine/meta-data" cloud_init_iso_image="/kvm/kvmimages/dnsserver_machine/cidata.iso"

[dns_server:vars]
vm_cpu=1
vm_memory=2048
vm_root_disk_size=20G

[all:vars]
kvm_vm_pool_dir="/kvm/kvmdata"
vm_recreate=true
#uncomment and edit if using RHEL
cloud_init_vm_image="${CLOUDIMAGE}"
manage_dns=true
dns_servers=[127.0.0.1] #DO NOT CHANGE THIS
search_domain=${DOMAINNAME}
dns_zone=10.90.30

#uncomment and edit if using RHEL
#RHEL Subscription Info
rhel_username=${RHEL_USERNAME}
rhel_password=${RHEL_PASSWORD}


#default RHEL user
rhel_user=${SSH_USERNAME}
rhel_user_password=${SSH_PASSWORD}
EOF
