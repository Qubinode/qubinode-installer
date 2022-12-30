#!/bin/bash

if [ $# -ne 2 ]; then 
    echo "No arguments provided"
    echo "Usage: $0 <rhel_username> <rhel_password>"
    exit 1
fi
rhsm_username=${1}
rhsm_password=${2}
sudo subscription-manager refresh
sudo subscription-manager attach --auto
subscription-manager repos --disable=*
subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
dnf update -y
subscription-manager repos --enable=rhceph-5-tools-for-rhel-8-x86_64-rpms
subscription-manager repos --enable=ansible-2.9-for-rhel-8-x86_64-rpms
dnf install ansible cephadm-ansible bind-utils -y
sleep 30s
nmcli con mod "System eth0" ipv4.dns "192.168.1.39"
sudo nmcli con mod "System eth0" ipv4.dns-search "lab.tosins-supermicro.io"
sudo service NetworkManager restart

curl https://raw.githubusercontent.com/tosin2013/qubinode-installer/master/kcli_plans/ceph/rhel8_ceph.sh --output /tmp/rhel8_ceph.sh

chmod +x /tmp/rhel8_ceph.sh

sed -i "s/RHEL_USERNAME/${rhsm_username}/g"  /tmp/rhel8_ceph.sh 
sed -i "s/RHEL_PASSWORD/${rhsm_password}/g"  /tmp/rhel8_ceph.sh 