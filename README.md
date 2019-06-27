# openshift-home-lab - v0.1.7
OpenShift Home Lab on RHEL

This document will explain how to get a home lab setup for Red Hat OpenShift on top of KVM for your home network.

## Requirements
* Server with at least 16 GB Memory
* Server With at least 1 TB of Secondary Hard Drive
* Ansible version 2.6 and up
* RHEL7
* dnspython
* pip [How to install pip on Red Hat Enterprise Linux?](https://access.redhat.com/solutions/1519803)
* mkdir ~/keys
* mkdir /kvmdata/
* OpenvSwitch  [openvswitch](https://www.linuxtechi.com/install-use-openvswitch-kvm-centos-7-rhel-7/)
* KVM

## Deployment Architecture
* [start_deployment](architecture/start_deployment_arch_diagram.png)

## Quick start
* install the following roles
  - for centos deployments ```ansible-galaxy install tosin2013.kvm_cloud_init_vm```
  - for RHEL deployments ```ansible-galaxy install tosin2013.rhel7_kvm_cloud_init```
  - for bind server
    ```
    ansible-galaxy install bertvv.bind
    ansible-galaxy install blofeldthefish.ansible-role-bind
    ```

* run the bootstrap.sh script

* (optional) deploy dns server
  -
  ```
  $ ./dns_server/deploy_dns_server.sh
  Usage for centos deployment: ./dns_server/deploy_dns_server.sh centos inventory.centos.dnsserver
  Usage for rhel deployment: ./dns_server/deploy_dns_server.sh rhel inventory.rhel.dnsserver username
  ```
* Modify inventory.openshift
* Modify inventory.3.11.centos.gluster
* Run ./start_deployment.sh
```
./start_deployment.sh  centos inventory.openshift inventory.3.11.centos.gluster
./start_deployment.sh  rhel inventory.openshift inventory.3.11.rhel.gluster
```
* To Delete Run ./delete_openshift_deployment.sh inventory.openshift

## Manual Deployment

1. install kvm
```
./install_kvm_packages.sh
```
2. Configure networking See [link](https://www.linux-kvm.org/page/Networking#Public_Bridge) I am using openvswitch in my deployment
3. Install  kvm_cloud_init_vm  and tosin2013.rhel7_kvm_cloud_init ansible roles in order to deploy KVM
```
ansible-galaxy install tosin2013.kvm_cloud_init_vm
ansible-galaxy install tosin2013.rhel7_kvm_cloud_init
```
4. Install and configure ansible role for  dns server
```
ansible-galaxy install bertvv.bind
ansible-galaxy install blofeldthefish.ansible-role-bind  
```
5. Run ssh add script
```
source ssh-add-script.sh
```
6. Update or modify the inventory file under dns_server/inventory based off your target OS.

7. run  deploy_dns_server.sh script
```
  ./dns_server/deploy_dns_server.sh rhel inventory.dnsserver
```

10. update kvm inventory under kvm_inventory based off your operating system
11. Run start_deployment.sh script as root to deploy the KVM machines
```
./start_deployment.sh  rhel inventory.rhel.openshift  v3.11.104
```

12. ssh into jumpbox and deploy openshift
  - copy ssh-add-script to jumpbox
  - edit redhat.3.11.inventory and copy to jumpbox
  - ssh to jumpbox
```
scp ssh-add-script.sh exampleuser@192.168.1.1=39:/tmp
cd ~/openshift-ansible
sudo htpasswd -c passwordFile username
source ssh-add-script.sh
ansible-playbook -i inventory.redhat  playbooks/prerequisites.yml
ansible-playbook -i inventory.redhat  playbooks/deploy_cluster.yml
```

## To-Do
* Cleanup functions in start_deployment.sh
* OCP 4.1 Compatibility
* better documentation
* finish manual install documentation


## Uninstall openshift
ansible-playbook -i inventory.redhat  playbooks/adhoc/uninstall.yml
ansible all -i inventory.redhat -a "rm -rf /etc/origin"

## Architecture

## Links
