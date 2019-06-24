#!/bin/bash
#Author: Tosin Akinosho
# Script used to generate openshift for openshift delopyment

if [ "$#" -ne 5 ]; then
  echo "Please pass the required information."
  echo "Example: $0 example.com v3.11.98 rhel-subscription-username rhel-subscription-password ssh-username"
  exit 1
fi

DOMAINNAME=$1
OPENSHIFT_RELEASE=$2
RHEL_USERNAME=$3
RHEL_PASSWORD=$4
SSH_USERNAME=$5

cat >inventory.3.11.rhel.gluster<<EOF
[OSEv3:children]
masters
nodes
etcd
glusterfs

[etcd]
master.ocp.${DOMAINNAME} openshift_public_hostname=master.ocp.${DOMAINNAME}

[masters]
master.ocp.${DOMAINNAME} openshift_public_hostname=master.ocp.${DOMAINNAME}

[nodes]
master.ocp.${DOMAINNAME} openshift_public_hostname=master.ocp.${DOMAINNAME} openshift_node_group_name='node-config-master'
node1.ocp.${DOMAINNAME} openshift_public_hostname=node1.ocp.${DOMAINNAME} openshift_node_group_name='node-config-infra'
node2.ocp.${DOMAINNAME} openshift_public_hostname=node2.ocp.${DOMAINNAME} openshift_node_group_name='node-config-infra'
node3.ocp.${DOMAINNAME} openshift_public_hostname=node3.ocp.${DOMAINNAME} openshift_node_group_name='node-config-compute'
node4.ocp.${DOMAINNAME} openshift_public_hostname=node4.ocp.${DOMAINNAME} openshift_node_group_name='node-config-compute'

[glusterfs]
node1.ocp.${DOMAINNAME} glusterfs_ip=192.168.1.11 glusterfs_zone=1  glusterfs_devices='["/dev/vdc"]'
node2.ocp.${DOMAINNAME} glusterfs_ip=192.168.1.12 glusterfs_zone=2 glusterfs_devices='["/dev/vdc"]'
node3.ocp.${DOMAINNAME} glusterfs_ip=192.168.1.13 glusterfs_zone=3 glusterfs_devices='["/dev/vdc"]'
node4.ocp.${DOMAINNAME} glusterfs_ip=192.168.1.14 glusterfs_zone=4 glusterfs_devices='["/dev/vdc"]'

[OSEv3:vars]
ansible_ssh_user=${SSH_USERNAME}
ansible_become=true
debug_level=2
openshift_release=${OPENSHIFT_RELEASE}
openshift_deployment_type=openshift-enterprise

oreg_url=registry.redhat.io/openshift3/ose-${component}:${version}
oreg_auth_user=${RHEL_USERNAME}
oreg_auth_password=${RHEL_PASSWORD}

openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider'}]
openshift_master_htpasswd_file=/home/tosin/openshift-ansible/passwordFile
openshift_docker_additional_registries=jumpbox.ocp.${DOMAINNAME}
openshift_docker_insecure_registries=jumpbox.ocp.${DOMAINNAME}
openshift_master_default_subdomain=apps.ocp.${DOMAINNAME}

#openshift operators
openshift_enable_olm=true
openshift_additional_registry_credentials=[{'host':'registry.connect.redhat.com','user':'${RHEL_USERNAME}','password':'${RHEL_PASSWORD},'test_image':'mongodb/enterprise-operator:0.3.2'}]

# registry
openshift_hosted_registry_storage_kind=glusterfs
openshift_hosted_registry_storage_volume_size=10Gi
openshift_hosted_registry_selector="node-role.kubernetes.io/infra=true"

# Container image to use for glusterfs pods
openshift_storage_glusterfs_image="registry.redhat.io/rhgs3/rhgs-server-rhel7:v3.11"

# Container image to use for glusterblock-provisioner pod
openshift_storage_glusterfs_block_image="registry.redhat.io/rhgs3/rhgs-gluster-block-prov-rhel7:v3.11"

# Container image to use for heketi pods
openshift_storage_glusterfs_heketi_image="registry.redhat.io/rhgs3/rhgs-volmanager-rhel7:v3.11"

# OCS storage cluster
openshift_storage_glusterfs_namespace=app-storage
openshift_storage_glusterfs_storageclass=true
openshift_storage_glusterfs_storageclass_default=true
openshift_storage_glusterfs_block_deploy=true
openshift_storage_glusterfs_block_host_vol_create=true
openshift_storage_glusterfs_block_host_vol_size=50
openshift_storage_glusterfs_block_storageclass=true
openshift_storage_glusterfs_block_storageclass_default=false

# metrics
openshift_metrics_install_metrics=true
openshift_metrics_storage_kind=dynamic
openshift_master_dynamic_provisioning_enabled=true
openshift_metrics_hawkular_hostname=hawkular-metrics.{{openshift_master_default_subdomain}}
openshift_metrics_cassandra_storage_type=pv
openshift_metrics_storage_volume_size=10Gi
openshift_metrics_cassanda_pvc_storage_class_name='glusterfs-storage-block'
openshift_metrics_hawkular_nodeselector={"node-role.kubernetes.io/infra":"true"}
openshift_metrics_cassandra_nodeselector={"node-role.kubernetes.io/infra":"true"}
openshift_metrics_heapster_nodeselector={"node-role.kubernetes.io/infra":"true"}

# logging
# openshift_logging_install_logging=true
# openshift_logging_es_pvc_dynamic=true
# openshift_logging_storage_kind=dynamic
# openshift_logging_es_pvc_size=10Gi
# openshift_logging_es_cluster_size=3
# openshift_logging_es_pvc_storage_class_name='glusterfs-storage-block'
# openshift_logging_kibana_nodeselector={"node-role.kubernetes.io/infra":"true"}
# openshift_logging_curator_nodeselector={"node-role.kubernetes.io/infra":"true"}
# openshift_logging_es_nodeselector={"node-role.kubernetes.io/infra":"true"}

# prometheous operator
# openshift_cluster_monitoring_operator_install=true
# openshift_cluster_monitoring_operator_node_selector={"node-role.kubernetes.io/infra":"true"}
# openshift_cluster_monitoring_operator_prometheus_storage_enabled=true
# openshift_cluster_monitoring_operator_alertmanager_storage_enabled=true
# openshift_cluster_monitoring_operator_prometheus_storage_capacity=10Gi
# openshift_cluster_monitoring_operator_alertmanager_storage_capacity=2Gi
# openshift_cluster_monitoring_operator_prometheus_storage_class_name='glusterfs-storage-block'
# openshift_cluster_monitoring_operator_alertmanager_storage_class_name='glusterfs-storage-block'
EOF
