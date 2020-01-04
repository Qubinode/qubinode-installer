#!/bin/bash

function collect_system_information() {
    MANUFACTURER=$(sudo dmidecode --string system-manufacturer)
    PRODUCTNAME=$(sudo dmidecode --string baseboard-product-name)
    AVAILABLE_MEMORY=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    AVAILABLE_HUMAN_MEMORY=$(free -h | awk '/Mem/ {print $2}')


    libvirt_pool_name=$(cat playbooks/vars/all.yml | grep libvirt_pool_name: | awk '{print $2}')
    AVAILABLE_STORAGE=$(sudo virsh pool-list --details | grep "${libvirt_pool_name}" |awk '{print $5*1024}')
     AVAILABLE_HUMAN_STORAGE=$(sudo virsh pool-list --details | grep "${libvirt_pool_name}" |awk '{print $5,$6}')
}

if [[ ! -f qubinode_profile.log ]]; then
    rm -rf qubinode_profile.log
    collect_system_information
cat >qubinode_profile.log<<EOF
Manufacturer: ${MANUFACTURER}
Product Name: ${PRODUCTNAME}

System Memory
*************
Avaliable Memory: ${AVAILABLE_MEMORY}
Avaliable Human Memory: ${AVAILABLE_HUMAN_MEMORY}

Storage Information
*******************
Avaliable Storage: ${AVAILABLE_STORAGE}
Avaliable Human Storage: ${AVAILABLE_HUMAN_STORAGE}

CPU INFO
***************
$(lscpu | egrep 'Model name|Socket|Thread|NUMA|CPU\(s\)')
EOF

fi

echo "SYSTEM REPORT"
cat qubinode_profile.log
