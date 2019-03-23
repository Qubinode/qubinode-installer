# openshift-home-lab - WIP
OpenShift Home Lab on RHEL

This document will explain how to get a home lab setup for Red Hat OpenShift on top of KVM for your home network.

## Requirements
* Server with at least 16 GB Memory
* Server With at least 1 TB of Hard Drive
* Ansible version 2.6 and up
* RHEL7 or CENTOS7
* dnspython
* pip [How to install pip on Red Hat Enterprise Linux?](https://access.redhat.com/solutions/1519803)
* mkdir ~/keys
* mkdir /kvmdata/
* oVirt or Red Hat Virtualation with OpenvSwith
* preconfigured [openvswitch](https://www.linuxtechi.com/install-use-openvswitch-kvm-centos-7-rhel-7/)

## Quick start
* install the following roles
  - for centos deployments ```ansible-galaxy install tosin2013.kvm_cloud_init_vm```
  - for RHEL deployments ```ansible-galaxy install tosin2013.rhel7_kvm_cloud_init```
  - for bind server ```ansible-galaxy install bertvv.bind```
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


eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

1. install kvm
```
./install_kvm_packages.sh
```
2. Configure networking See [link](https://www.linux-kvm.org/page/Networking#Public_Bridge) I am using openvswitch in my deployment
3. Install  kvm_cloud_init_vm  to do automated installed of kvm via ansible
```
ansible-galaxy install tosin2013.kvm_cloud_init_vm
```
4. Install and configure dns server
```
ansible-galaxy install bertvv.bind
```
5. Run ssh add script
```
source ssh-add-script.sh
```
6. run  deploy-dns-kvm.yml  script
```
ansible-inventory -i inventory.dnserver  --list
ansible-playbook -i inventory.dnsserver deploy_dns_kvm.yml
```
7. create inventory.vm.dnserver script
```
cat dnsserver
```
8. Update deploy_dns_server.yml

9. Run deploy-dns-server.yml playbook
```
ansible-playbook -i inventory.vm.dnsserver deploy_dns_server.yml

```
10. update inventory.openshift file
11. Run deploy_openshift_vms.yml playbook as root
```
ansible-playbook -i inventory.openshift deploy_openshift_vms.yml  --become
```
# Generate inventory.vm.provision script
```
scripts/provision_openshift_nodes.sh
```

```
ansible-playbook -i inventory.openshift  tasks/hosts_generator.yml

ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=jumpboxdeploy" --extra-vars="rhel_user=exampleuser"

ansible-playbook -i inventory.vm.provision tasks/push_hosts_file.yml --extra-vars="machinename=OSEv3" --extra-vars="rhel_user=exampleuser"
```
as user
```
scripts/generation_jumpbox_ssh_key.sh  exampleuser 192.168.1.129
scripts/share_keys.sh 192.168.1.133 exampleuser
```

# Configure jumpbox
```
ansible-playbook -i inventory.vm.provision tasks/openshift_jumpbox-v3.11.yml  --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=exampleuser"
```

```
ansible-playbook -i inventory.vm.provision tasks/configure_docker_regisitry.yml --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=exampleuser" --become
```
```
ansible-playbook -i inventory.vm.provision tasks/openshift_nodes-v3.11.yml   --extra-vars "rhel_user=exampleuser"
```

copy ssh-add-script to jumpbox
edit redhat.3.11.inventory and copy to jumpbox
ssh to jumpbox
```
scp ssh-add-script.sh exampleuser@10.90.30.156:/tmp
cd ~/openshift-ansible
sudo htpasswd -c passwordFile username
source ssh-add-script.sh
ansible-playbook -i inventory.redhat  playbooks/prerequisites.yml
ansible-playbook -i inventory.redhat  playbooks/deploy_cluster.yml
```

## To-Do
* create [Public Bridge](https://www.linux-kvm.org/page/Networking#Public_Bridge) script
* Cleanup functions in start_deployment.sh
* OCP 4.1 Compatibility
* better documetnation
* finish manual install documentation  


## Uninstall openshift
ansible-playbook -i inventory.redhat  playbooks/adhoc/uninstall.yml
ansible all -i inventory.redhat -a "rm -rf /etc/origin"

## Architecture

## Links
