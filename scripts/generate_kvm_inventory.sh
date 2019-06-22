#!/bin/bash
#Author: Tosin Akinosho
# Script used to generate kvm inventory for inventory

if [ "$#" -ne 6 ]; then
  echo "Please pass the required information."
  echo "Example: $0 example.com 192.168.1.5 rhel-subscription-username rhel-subscription-password ssh-username ssh-password"
  exit 1
fi

DOMAINNAME=$1
DNSSERVERIP=$2
CLOUDIMAGE="rhel-server-7.6-x86_64-kvm.qcow2"
RHEL_USERNAME=$3
RHEL_PASSWORD=$4
SSH_USERNAME=$5
SSH_PASSWORD=$6


cat > inventory.rhel.openshift <<EOF
#/
#/ This inventory includes a jumpbox, master, node and load balancer for openshift
#/

[jumpbox]
jumpbox vm_name=jumpbox vm_local_hostname=jumpbox.ocp.${DOMAINNAME} vm_hostname=jumpbox.ocp.${DOMAINNAME} vm_data_dir="/kvmimages/jumpbox_machine" cloud_init_user_data="/kvmimages/jumpbox_machine/user-data"  cloud_init_meta_data="/kvmimages/jumpbox_machine/meta-data" cloud_init_iso_image="/kvmimages/jumpbox_machine/cidata.iso"

[jumpbox:vars]
vm_cpu=2
vm_memory=4096
vm_root_disk_size=30G

[master]
master vm_name=master vm_local_hostname=master.ocp.${DOMAINNAME} vm_hostname=master.ocp.${DOMAINNAME} vm_data_dir="/kvmimages/master_machine" cloud_init_user_data="/kvmimages/master_machine/user-data"  cloud_init_meta_data="/kvmimages/master_machine/meta-data" cloud_init_iso_image="/kvmimages/master_machine/cidata.iso"

[master:vars]
vm_cpu=4
vm_memory=16384
vm_root_disk_size=120G

[nodes]
node1 vm_name=node1 vm_local_hostname=node1.ocp.${DOMAINNAME} vm_hostname=node1.ocp.${DOMAINNAME} vm_data_dir="/kvmimages/node1_machine" cloud_init_user_data="/kvmimages/node1_machine/user-data"  cloud_init_meta_data="/kvmimages/node1_machine/meta-data" cloud_init_iso_image="/kvmimages/node1_machine/cidata.iso"
node2 vm_name=node2 vm_local_hostname=node2.ocp.${DOMAINNAME} vm_hostname=node2.ocp.${DOMAINNAME} vm_data_dir="/kvmimages/node2_machine" cloud_init_user_data="/kvmimages/node2_machine/user-data"  cloud_init_meta_data="/kvmimages/node2_machine/meta-data" cloud_init_iso_image="/kvmimages/node2_machine/cidata.iso"

[nodes:vars]
vm_cpu=2
vm_memory=8192
vm_root_disk_size=80G

[lb]
lb vm_name=lb vm_local_hostname=lb.ocp.${DOMAINNAME} vm_hostname=lb.ocp.${DOMAINNAME} vm_data_dir="/kvmimages/lb_machine" cloud_init_user_data="/kvmimages/lb_machine/user-data"  cloud_init_meta_data="/kvmimages/lb_machine/meta-data" cloud_init_iso_image="/kvmimages/lb_machine/cidata.iso"

[lb:vars]
vm_cpu=1
vm_memory=2048
vm_root_disk_size=20G

# Create an OSEv3 group that contains the masters and nodes groups
#[OSEv3:children]
#masters
#nodes
#etcd
#lb
#nfs


[all:vars]
kvm_vm_pool_dir="/kvmimages/"
vm_recreate=true
cloud_init_vm_image="${CLOUDIMAGE}"


manage_dns=true
dns_servers=[${DNSSERVERIP}] # googles ['8.8.8.8','8.8.4.4']
search_domain=ocp.${DOMAINNAME}

#RHEL Subscription Info
rhel_username=${RHEL_USERNAME}
rhel_password=${RHEL_PASSWORD}

#default RHEL user
rhel_user=${SSH_USERNAME}
rhel_user_password=${SSH_PASSWORD}

EOF
