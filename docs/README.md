#  Qubinode Overview

A Qubinode is a bare metal node that uses the qubinode-installer to configure RHEL to function as a KVM host. The qubinode-installer can then be used to deploy additional Red Hat products as VMs running atop the Qubinode. 

## Currently Supported Products
* [Red Hat OpenShift Platform](openshift4_installation_steps.md)
* [Red Hat Identity Managment](idm.md)
* [Red Hat Enterprise Linux](rhel_vms.md)

## Products in Development
* [Ansible Automation Platform](ansible_platform.md)
* [Red Hat Satellite](redhat_satellite.md)

# Getting Started

The first step is to get RHEL installed on your hardware

## Get Subscriptions

-  Get your [No-cost developer subscription](https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux/) for RHEL.
-  Get a Red Hat OpenShift Container Platform (OCP) [60-day evalution subscription](https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG).

## Install Red Hat Enterprise Linux
A bare metal system running RHEL. Follow the [RHEL Installation Walkthrough](https://developers.redhat.com/products/rhel/hello-world#fndtn-rhel) to get RHEL installed on your hardware. When installing RHEL, for the software selection, **Base Environment** choose one of the following:

1. Virtualization Host
2. Server with GUI

If you choose **Server with GUI**, make sure from the **Add-ons for Selected Evironment** you select the following:

- Virtualization Hypervisor 
- Virtualization Tools

**_TIPS_**
> * If using the recommend storage of one ssd and one NVME, install RHEL on the ssd, not the NVME. 
>  * The RHEL installer will delicate the majority of your storage to /home,  you can choose **"I will configure partitioning"** to have control over this.
>  * Set root password and create admin user with sudo privilege

### The qubinode-installer

Downlaod and extract the qubinode-installer as a non root user.

```shell=
cd $HOME
wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
unzip master.zip
rm master.zip
mv qubinode-installer-master qubinode-installer
```

### Deploy a Red Hat Product

At this point you refer to the [documentation](#Currently-Supported-Products) for the product you want to install.
