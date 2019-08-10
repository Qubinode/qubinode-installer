#!/usr/bin/env bash
# To-do Configure static option
#scripts/configure-libvirt-network.sh
NETWORKNAME="lunchbox"

cat >/etc/sysconfig/network-scripts/ifcfg-eno1<<EOF
DEVICE=eno1
NAME=VMBR0SLAVE
TYPE=Ethernet
HWADDR=$(ifconfig eno1 | grep ether | awk '{print $2}')
BOOTPROTO=none
ONBOOT=yes
BRIDGE=vmbr0
ZONE=public
EOF

cat >/etc/sysconfig/network-scripts/ifcfg-vmbr0<<EOF
DEVICE=vmbr0
NAME=mgmnet
TYPE=Bridge
PREFIX=24
BOOTPROTO=dhcp
ONBOOT=yes
DELAY=0
ZONE=public
EOF

systemctl restart network

cat >${NETWORKNAME}<<EOF
<network connections='1'>
  <name>${NETWORKNAME}</name>
  <uuid>$(uuidgen)</uuid>
  <forward mode='bridge'/>
  <bridge name='vmbr0'/>
</network>
EOF

virsh net-create ${NETWORKNAME}
