#  Installing an OpenShift 4.3 Cluster on a Single Node

The following documentation will help you deploy an OpenShift Container Platform (OCP) 4.3 cluster, on a single node.
The installation steps deploys a production like OCP4 clsuter, in a enviorment with 3 masters and 3 workers on a KVM hosts running Red Hat Enterprise Linux (RHEL) 


## Prerequisites

#### Get Subscriptions

-  Get your [No-cost developer subscription](https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux/) for RHEL.
-  Get a Red Hat OpenShift Container Platform (OCP) [60-day evalution subscription](https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG).

#### Install Red Hat Enterprise Linux
A bare metal system running RHEL. Follow the [RHEL Installation Walkthrough](https://developers.redhat.com/products/rhel/hello-world#fndtn-rhel) to get RHEL installed on your hardware. When installing RHEL, for the software selection, **Base Environment** choose one of the following:

1. Virtualization Host
2. Server with GUI

If you choose **Server with GUI**, make sure from the **Add-ons for Selected Evironment** you select the following:

- Virtualization Hypervisor 
- Virtualization Tools

_TIPS_
* If using the recommend storage options install RHEL on the ssd, not the NVME. 
* The RHEL installer will delicate the majority of your storage to /home, you can choose "I will configure partitioning" to have control over this.
* Set root password and create admin user with sudo privilege

## Install OpenShift

### The qubinode-installer

Downlaod and extract the qubinode-installer as a non root user.

```
cd $HOME
wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
unzip master.zip
rm master.zip
mv qubinode-installer-master qubinode-installer
```
Before you running the qubinode-installer, you will need to grab the RHEL qcow image and your OpenShift 4 pull secret.

**Red Hat Enterprise Linux 7 Qcow Image**

*Download the qcow image*
From your web browser:
- Navigate to: https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software
- Find **Red Hat Enterprise Linux 7.8 KVM Guest Image** and right click on the *Download Now* box
- Switch to your terminal and run the below command replacing **insert-url-here** 

```
cd $HOME/qubinode-installer
wget -c "insert-url-here" -O rhel-server-7.8-x86_64-kvm.qcow2 
```

**OpenShift Pull Secret**

- Navigate to [https://cloud.redhat.com/openshift/install/metal/user-provisioned](https://cloud.redhat.com/openshift/install/metal/user-provisioned)
- Under downloads copy or download you pull secret to ```$HOME/qubinode-installer/pull-secret.txt```


### Install Options  
- Quick Start - Answer questions from the installer to complete installation of OpenmShift 4.x.
- Advanced - Step through the different Qubinode modules to complete installation.

#### Quick start
```
./qubinode-installer
```

*Select Option 1: Continue with the default installation*

```
  ****************************************************************************
        Red Hat Openshift Container Platform 4 (OCP4)

    The default product option is to install OCP4. The deployment consists of
    3 masters and 3 computes. The standard hardware profile is the minimum
    hardware profile required for the installation. In addition to meeting the
    minimum hardware profile requirement, the installation requires a valid
    pull-secret. If you are unable to obtain a pull-secret, exit the install
    and choose OKD from menu option 2.

    Hardware profiles are defined as:
      Minimal     - 30G Memory and 370G Storage
      Standard    - 128G Memory and 900G Storage
      Custom      - 128G Memory and 1340G Storage

  ****************************************************************************

1) Continue with the default installation
2) Display other options
#? 1
```

*This will perform the following*
* Configure server for KVM.
* Deploy an idm server to be used as DNS.
* Deploy OpenShift 4.
* Optional: Configure NFS Provisioner

#### Advanced installation
Use this when you would like to step thru the installation process.

****setup playbooks vars and user sudoers****  
```
./qubinode-installer -m setup
```

****register host system to Red Hat****  
```
./qubinode-installer -m rhsm
```
****update to RHEL 7.7 if you are using 7.6****
```
sudo yum update -y
```

****setup host system as an ansible controller****
```
./qubinode-installer -m ansible
```

****setup host system as an ansible controller****
```
./qubinode-installer -m host
```

****install idm dns server****
```
./qubinode-installer -p idm
```

****Optional: Uninstall idm dns server****

This may be used when there is an issue with the deployment. Note that idm is required for OpenShift 4.x installations.
```
./qubinode-installer  -p idm -d
```

****Install OpenShift 4.x****
```
./qubinode-installer -p ocp4
```

****Additional options**** 

*To configure shutdown before 24 hours*
```
$ cd /home/$USER/qubinode-installer
$ ansible-playbook playbooks/deploy_ocp4.yml  -t enable_shutdown
```

*To configure nfs-provisioner for registry*
```
$ cd /home/$USER/qubinode-installer
$ ansible-playbook playbooks/deploy_ocp4.yml  -t nfs
```

*To configure localstroage*
```
$ cd /home/$USER/qubinode-installer
$ ansible-playbook playbooks/deploy_ocp4.yml  -t localstorage
```

## Deployment Post Steps
#### How to access OpenShift Cluster
* Option 1: Add dns server to /etc/resolv.conf on your computer.
  - Or run script found under lib/qubinode_dns_configurator.sh
* Option 2: Add dns server to router so all machines can access the OpenShift Cluster.
