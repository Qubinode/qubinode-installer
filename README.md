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

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa


## To-Do
* create [Public Bridge](https://www.linux-kvm.org/page/Networking#Public_Bridge) script
* Generate key on jumpbox
* Pass ssh keys automatially
* Ansible config file edits
  - host_key_checking=False
  - private_key_file=/home/tosin/.ssh/id_rsa
  - sudo_user
* add ansible become ansible_become=yes to minimal file

# enable subscriuptions on workers
subscription-manager repos --enable="rhel-7-server-rpms" \
   --enable="rhel-7-server-extras-rpms" \
   --enable="rhel-7-server-ose-3.9-rpms" \
   --enable="rhel-7-fast-datapath-rpms" \
   --enable="rhel-7-server-ansible-2.4-rpms"

# to minimal file
openshift_enable_unsupported_configurations=True
openshift_deployment_type


## Architecture

## Links
