#!/bin/bash
sudo yum update -y
sudo yum install qemu-kvm libvirt -y
sudo yum install virt-install libvirt-python virt-manager virt-install libvirt-client -y
#sudo systemctl enable libvirtd || exit $?
#sudo systemctl start libvirtd || exit $?
#sudo systemctl status libvirt
sudo virt-host-validate 

echo "Useful commands: "
echo "virsh nodeinfo"
echo "virsh domcapabilities"
