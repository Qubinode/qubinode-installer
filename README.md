# openshift-home-lab
OpenShift Home Lab on RHEL

This document will explain how to get a home lab setup for Red Hat OpenShift on top of KVM for your home network.

## Requirements
* Server with at least 64 GB Memory
* Server With at least 1 TB of Secondary Hard Drive
* Ansible version 2.6 and up
* RHEL7
* dnspython
* pip [How to install pip on Red Hat Enterprise Linux?](https://access.redhat.com/solutions/1519803)
* mkdir ~/keys
* mkdir /kvm
* mkdir /kvm/kvmdata
* mkdir /kvm/kvmimages/
* OpenvSwitch  [openvswitch](https://www.linuxtechi.com/install-use-openvswitch-kvm-centos-7-rhel-7/)
* KVM


## Deployment Architecture
* [start_deployment](architecture/start_deployment_arch_diagram.png)

## System Verification
Before running the following scripts verify that CPU virtualization extensions are enabled.

```
$ grep -E "vmx|svm" /proc/cpuinfo
```
If this command shows any output, the required extensions are enabled.

If this command shows no output, either your hardware does not support virtualization features, or these features are not enabled in your system's BIOS. See the Virtualization Deployment and Administration Guide for details on how to check for, and enable these features.

[More info](https://access.redhat.com/articles/1344173#Q_how-verify-enable-cpu-extensions)

**Hard drive Validation**
Ensure you are using two hard drives for a recommend setup. One hard drive should be ssh and the second hard drive should be NVME.
* SSD will contain your host operating system.
* NVME should be used for data generated from the KVM environment. Such as the hard drive and data for the kvms. This will be the /kvm/ path

Review the link on how to create a lvm for the /kvm/ directory.
* https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/logical_volume_manager_administration/lvm_examples

* Downloaded a RHEL 7.6 KVM image from redhat.com to the /kvm/data directory
- Deployed with Red Hat Enterprise Linux 7.6 KVM Guest Image: https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.6/x86_64/product-software

## Quick start

* install kvm
```
./install_kvm_packages.sh
```
* Build an OpenvSwitch RPM for your server and install it to your server [Fedora, RHEL 7.x Packaging for Open vSwitch](http://docs.openvswitch.org/en/latest/intro/install/fedora/)
- You can also review the [configure-ovs-interface.sh](scripts/configure-ovs-interface.sh) script
* install the following roles
  - for centos deployments ```ansible-galaxy install tosin2013.kvm_cloud_init_vm```
  - for RHEL deployments ```ansible-galaxy install tosin2013.rhel7_kvm_cloud_init```
  - for bind server
    ```
    ansible-galaxy install bertvv.bind
    ansible-galaxy install blofeldthefish.ansible-role-bind
    ```
  - for power management
  ```
  ansible-galaxy install tosin2013.ocp_power_management
  ```
* Create directory for scripts
```
mkdir -p /opt/openshift-home-lab/Packages/
```
* copy repo to /opt/openshift-home-lab/Packages/openshift-home-lab/
```
cd  /opt/openshift-home-lab/Packages/
git clone https://github.com/tosin2013/openshift-home-lab.git
```

* run the bootstrap.sh script
```
cd openshift-home-lab
run ./bootstrap.sh
```

## Manual Deployment

1. install kvm
```
./install_kvm_packages.sh
```
2. Build an OpenvSwitch RPM for your server and install it to your server [Fedora, RHEL 7.x Packaging for Open vSwitch](http://docs.openvswitch.org/en/latest/intro/install/fedora/)
- You can also review the [configure-ovs-interface.sh](scripts/configure-ovs-interface.sh) script

3. Install ansible
```
yum install ansible -y
```

4. Install  kvm_cloud_init_vm  and tosin2013.rhel7_kvm_cloud_init ansible roles in order to deploy KVM
```
ansible-galaxy install tosin2013.kvm_cloud_init_vm
ansible-galaxy install tosin2013.rhel7_kvm_cloud_init
```
5. Install and configure ansible role for  dns server
```
ansible-galaxy install bertvv.bind
ansible-galaxy install blofeldthefish.ansible-role-bind  
```
6. Install and configure ansible role for power management
```
ansible-galaxy install tosin2013.ocp_power_management
```
7. Create directory for scripts
```
mkdir -p /opt/openshift-home-lab/Packages/
```
8. copy repo to /opt/openshift-home-lab/Packages/openshift-home-lab/ -> This should be changed to a variable  in the future.
```
cd  /opt/openshift-home-lab/Packages/
git clone https://github.com/tosin2013/openshift-home-lab.git
```
9. Generate ssh key for ansible for ansible to use.
```
ssh-keygen
```

10. Run ssh add script
```
source ssh-add-script.sh
```
11. Update or modify the inventory file under dns_server/inventory based off your target OS.

12. run  deploy_dns_server.sh script
```
  ./dns_server/deploy_dns_server.sh rhel inventory.dnsserver
```

13. update kvm inventory under kvm_inventory based off your operating system  and move it into the same directory as start_deployment.

14. update the openshift inventory under openshift_inventory and move it into the same directory as start_deployment.

15. Run start_deployment.sh script as root to deploy the KVM machines
```
./start_deployment.sh  rhel inventory.rhel.openshift  v3.11.104
```

16. ssh into jumpbox and deploy openshift
  - copy ssh-add-script to jumpbox
  - edit redhat.3.11.inventory and copy to jumpbox
  - ssh to jumpbox
    ```
    # This is an Example
    scp ssh-add-script.sh exampleuser@jumpbox.ocp.example.com:/tmp
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
* Test deployment with RHEL8
* Test Deployment with RHEL 7.7


## Uninstall openshift
```
ansible-playbook -i inventory.redhat  playbooks/adhoc/uninstall.yml  
ansible all -i inventory.redhat -a "rm -rf /etc/origin"  
```
## To delete deployment
```
./delete_openshift_deployment.sh inventory.openshift
```

## Architecture
[Link](https://github.com/tosin2013/openshift-home-lab/tree/master/architecture)

## Links

## Acknowledgments
* [bertvv](https://github.com/bertvv)
* [karlmdavis](https://github.com/karlmdavis)
* [Jooho](https://github.com/Jooho)

## Author
Tosin Akinosho - [tosin2013](https://github.com/tosin2013)  
Open to committers  
