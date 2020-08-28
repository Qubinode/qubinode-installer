#  Qubinode Overview

A Qubinode is a bare metal node that uses the qubinode-installer to configure RHEL to function as a KVM host. The qubinode-installer can then be used to deploy additional Red Hat products as VMs running atop the Qubinode. 

# Getting Started

The first step is to get RHEL installed on your hardware

## Get Subscriptions

-  Get your [No-cost developer subscription](https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux/) for RHEL.
-  Get a Red Hat OpenShift Container Platform (OCP) [60-day evalution subscription](https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG).

## Install Red Hat Enterprise Linux
A bare metal system running Red Hat Enterprise Linux 8. Follow the [RHEL Installation Walkthrough](https://developers.redhat.com/products/rhel/hello-world#fndtn-rhel) to get RHEL installed on your hardware. When installing RHEL, for the software selection, **Base Environment** choose one of the following:

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
wget https://github.com/Qubinode/qubinode-installer/archive/main.zip
unzip main.zip
rm main.zip
mv qubinode-installer-main qubinode-installer
```

### Qubinode Setup

The below commands ensure your system is setup as a KVM host.
The qubinode-installer needs to run as a regular user.

* setup   - ensure your username is setup for sudoers
* rhsm    - ensure your rhel system is registered to Red Hat
* ansible - ensure your rhel system is setup for to function as a ansible controller
* kvmhost    - ensure your rhel system is setup as a KVM host

> Go [here](qubinode/qubinode-menu-options.adoc) for additional qubinode options.

```shell
./qubinode-installer -m setup
./qubinode-installer -m rhsm
./qubinode-installer -m ansible
./qubinode-installer -p kvmhost
```

At this point you should be able to acces the RHEL system via the cockpit web interface on:
```
https://SERVER_IP:9090
```
## Deploy a Red Hat Product

Most products depends on the latest rhel 7 or 8 qcow image. You can either manually download them or provide your RHSM api token and the installer will download these files for you.

#### Getting the RHEL 7 Qcow Image
<table>
  <tr>
   <td>Using Token
   </td>
   <td>Downloading
   </td>
  </tr>
  <tr>
   <td>Navigate to <a href="https://access.redhat.com/management/api">RHSM API</a> to generate a token and save it as <strong>rhsm_token</strong>. This token will be used to download the rhel qcow image. 
   </td>
   <td>From your web browser, navigate to <a href="https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software">Download Red Hat Enterprise Linux</a>. Download the qcow image matching this checksum the below checksum.
   </td>
  </tr>
</table>

Follow the same steps to get the RHEL 8 qcow image.

If you are using tokens it should be:
```
* $HOME/qubinode-installer/rhsm_token
```

If you downloaded the files instead, confirm that the project directory list the qcow images below or later versions:
```
* $HOME/qubinode-installer/rhel-server-7.8-x86_64-kvm.qcow2
* $HOME/qubinode-installer/rhel-8.2-x86_64-kvm.qcow2
```

At this point you refer to the [documentation](#Currently-Supported-Products) for the product you want to install.

## Currently Supported Products
* [Red Hat OpenShift Platform](qubinode/openshift4_installation_steps.md)
* [OKD - The Community Distribution of Kubernetes](qubinode/okd4_installation_steps.md)
* [Red Hat Identity Managment](qubinode/idm.md)
* [Red Hat Enterprise Linux](qubinode/rhel_vms.md)

## Products in Development
* [Ansible Automation Platform](qubinode/ansible_platform.md)
* [Red Hat Satellite](qubinode/qubinode_satellite_install.md)
