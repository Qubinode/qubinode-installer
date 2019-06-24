#!/bin/bash

#Setup guest network up/down script.
# cat /etc/ovs-ifup
cat > /etc/ovs-ifup <<EOF
#!/bin/sh
switch='ovs0'
/sbin/ifconfig $1 0.0.0.0 up
ovs-vsctl add-port ${switch} $1
EOF

#cat /etc/ovs-ifdown
cat > /etc/ovs-ifdown <<EOF
#!/bin/sh
switch='ovs0'
/sbin/ifconfig $1 0.0.0.0 down
ovs-vsctl del-port ${switch} $1
EOF

# Configure the network script.
cat > /etc/sysconfig/network-scripts/ifcfg-eno1 <<EOF
DEVICE=eno1
BOOTPROTO=none
HWADDR=$(ifconfig eno1 | grep ether | awk '{print $2}')
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSPort
OVS_BRIDGE=ovs0
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-ovs0 <<EOF
DEVICETYPE=ovs
DEVICE=ovs0
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSBridge
BOOTPROTO=dhcp
OVSBOOTPROTO=dhcp
OVSDHCPINTERFACES=eno1
EOF

systemctl start openvswitch.service
systemctl enable openvswitch.service

systemctl restart network.service

ovs-vsctl show
