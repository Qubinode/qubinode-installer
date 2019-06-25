#!/bin/bash
#Author: Tosin Akinosho
# Script used to generate kvm inventory for kvm deployments

if [ ! -f bootstrap_env ]; then
  echo "bootstrap_env was not found!!!"
  echo "Plesae run bootstrap.sh again to configure bootstrap_env"
  exit 1
fi

source bootstrap_env
CLOUDIMAGE="rhel-server-7.6-x86_64-kvm.qcow2"

cat > inventory.rhel.openshift <<EOF
#/
#/ This inventory includes a jumpbox, master, node and load balancer for openshift
#/

[jumpbox]
jumpbox vm_name=jumpbox vm_local_hostname=jumpbox.ocp.${DOMAINNAME} vm_hostname=jumpbox.ocp.${DOMAINNAME} vm_data_dir="/kvm/kvmimages/jumpbox_machine" cloud_init_user_data="/kvm/kvmimages/jumpbox_machine/user-data"  cloud_init_meta_data="/kvm/kvmimages/jumpbox_machine/meta-data" cloud_init_iso_image="/kvm/kvmimages/jumpbox_machine/cidata.iso"

[jumpbox:vars]
vm_cpu=2
vm_memory=4096
vm_root_disk_size=30G

[master]
master vm_name=master vm_local_hostname=master.ocp.${DOMAINNAME} vm_hostname=master.ocp.${DOMAINNAME} vm_data_dir="/kvm/kvmimages/master_machine" cloud_init_user_data="/kvm/kvmimages/master_machine/user-data"  cloud_init_meta_data="/kvm/kvmimages/master_machine/meta-data" cloud_init_iso_image="/kvm/kvmimages/master_machine/cidata.iso"

[master:vars]
vm_cpu=4
vm_memory=16384
vm_root_disk_size=80G
#Storage Options
#block_size "bs" is the block size that will be used to read and/ or write the file. Increasing this can help with performance  or dictate how much data will be read or written.
#count is the number of blocks that will be used.
#normal External storage Options could be used for containers
externalstorage=true
ext_block_size=100G
ext_block_count=1024
# GlusterFS storage Options can be  used with OpenShift deployments
glusterstorage=false
gluster_block_size=30G
gluster_block_count=1024

[nodes]
node1 vm_name=node1 vm_local_hostname=node1.ocp.${DOMAINNAME} vm_hostname=node1.ocp.${DOMAINNAME} vm_data_dir="/kvm/kvmimages/node1_machine" cloud_init_user_data="/kvm/kvmimages/node1_machine/user-data"  cloud_init_meta_data="/kvm/kvmimages/node1_machine/meta-data" cloud_init_iso_image="/kvm/kvmimages/node1_machine/cidata.iso"
node2 vm_name=node2 vm_local_hostname=node2.ocp.${DOMAINNAME} vm_hostname=node2.ocp.${DOMAINNAME} vm_data_dir="/kvm/kvmimages/node2_machine" cloud_init_user_data="/kvm/kvmimages/node2_machine/user-data"  cloud_init_meta_data="/kvm/kvmimages/node2_machine/meta-data" cloud_init_iso_image="/kvm/kvmimages/node2_machine/cidata.iso"
node3 vm_name=node3 vm_local_hostname=node3.ocp.${DOMAINNAME} vm_hostname=node3.ocp.${DOMAINNAME} vm_data_dir="/kvm/kvmimages/node3_machine" cloud_init_user_data="/kvm/kvmimages/node3_machine/user-data"  cloud_init_meta_data="/kvm/kvmimages/node3_machine/meta-data" cloud_init_iso_image="/kvm/kvmimages/node3_machine/cidata.iso"
node4 vm_name=node4 vm_local_hostname=node4.ocp.${DOMAINNAME} vm_hostname=node4.ocp.${DOMAINNAME} vm_data_dir="/kvm/kvmimages/node4_machine" cloud_init_user_data="/kvm/kvmimages/node4_machine/user-data"  cloud_init_meta_data="/kvm/kvmimages/node4_machine/meta-data" cloud_init_iso_image="/kvm/kvmimages/node4_machine/cidata.iso"

[nodes:vars]
vm_cpu=2
vm_memory=8192
vm_root_disk_size=20G
#Storage Options
#block_size "bs" is the block size that will be used to read and/ or write the file. Increasing this can help with performance  or dictate how much data will be read or written.
#count is the number of blocks that will be used.
#normal External storage Options could be used for containers
externalstorage=true
ext_block_size=60G
ext_block_count=1024
# GlusterFS storage Options can be  used with OpenShift deployments
glusterstorage=true
gluster_block_size=200G
gluster_block_count=1024


[lb]
lb vm_name=lb vm_local_hostname=lb.ocp.${DOMAINNAME} vm_hostname=lb.ocp.${DOMAINNAME} vm_data_dir="/kvm/kvmimages/lb_machine" cloud_init_user_data="/kvm/kvmimages/lb_machine/user-data"  cloud_init_meta_data="/kvm/kvmimages/lb_machine/meta-data" cloud_init_iso_image="/kvm/kvmimages/lb_machine/cidata.iso"

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
kvm_vm_pool_dir="/kvm/kvmdata"
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
