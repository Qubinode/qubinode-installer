#!/bin/bash

BOOTSTRAP=$(sudo virsh net-dumpxml ocp42 | grep  bootstrap | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
COREOS_IP=$(sudo virsh net-dumpxml ocp42 | grep  bootstrap  | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
ansible-playbook playbooks/ocp4_07_deploy_bootstrap_vm.yml  -e vm_mac_address=${BOOTSTRAP} -e coreos_host_ip=${COREOS_IP}

for i in {0..2}
do
    MASTER=$(sudo virsh net-dumpxml ocp42 | grep  master-${i} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
    COREOS_IP=$(sudo virsh net-dumpxml ocp42 | grep  master-${i} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
    ansible-playbook playbooks/ocp4_07.1_deploy_master_vm.yml  -e vm_mac_address=${MASTER}   -e vm_name=master-${i} -e coreos_host_ip=${COREOS_IP}
    sleep 10s
done

for i in {0..1}
do
  COMPUTE=$(sudo virsh net-dumpxml ocp42 | grep  compute-${i} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
  COREOS_IP=$(sudo virsh net-dumpxml ocp42 | grep   compute-${i} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
  ansible-playbook playbooks/ocp4_07.2_deploy_compute_vm.yml  -e vm_mac_address=${COMPUTE}   -e vm_name=compute-${i} -e coreos_host_ip=${COREOS_IP}
  sleep 10s
done


i="$(sudo virsh list | grep running |wc -l)"

while [ $i -gt 1 ]
do
  echo "waiting for coreos first boot to complete current count ${i}"
  sleep 10s
  i="$(sudo virsh list | grep running |wc -l)"
done
