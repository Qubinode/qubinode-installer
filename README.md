# openshift-home-lab
OpenShift Home Lab on RHEL

This document will explain how to get a home lab setup for Red Hat OpenShift on top of KVM for your home network.

## Requirements
* Server with at least 16 GB Memory
* Server With at least 1 TB of Hard Drive
* Ansible version 2.7
* RHEL7

## Deployment
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
5. configure enviornments/dns_server_env file
6. run deploy-rhel7-kvm.sh script
```
sudo ./deploy-rhel7-kvm.sh enviornments/dns_server_env
```
7. Configure deploy-dns-server.yml and edit inventory file
8. Run deploy-dns-server.yml playbook
```
ansible-playbook -i inventory deploy-dns-server.yml  --become
```
9. update inventory.openshift file
10. Run deploy_openshift_vms.yml playbook
```
ansible-playbook -i inventory.openshift deploy_openshift_vms.yml  --become
```
# Generate inventory.vm.provision script
```
scripts/provision_openshift_nodes.sh
```

Configure jumpbox
```
ansible-playbook -i inventory.vm.ptrovision tasks/openshift_jumpbox.yml
```

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa


sudo htpasswd -c passwordFile username


## To-Do
* create [Public Bridge](https://www.linux-kvm.org/page/Networking#Public_Bridge) script
* write entries to dns server
* Generate key on jumpbox
* create a /etc/hosts file for nodes
* Pass ssh keys automatially
* Ansible config file edits
  - host_key_checking=False
  - private_key_file=/home/tosin/.ssh/id_rsa
  - sudo_user
* add ansible become ansible_become=yes to minimal file

# to minimal file
openshift_enable_unsupported_configurations=True
openshift_deployment_type

fix penshift_node_labes
## Architecture

## Links
