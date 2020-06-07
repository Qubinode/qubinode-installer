#  Installing an OpenShift 4.x Cluster on a Single Node

The following documentation will help you deploy an OpenShift Container Platform (OCP) 4.3 cluster, on a single node.
The installation steps deploys a production like OCP4 clsuter, in a enviorment with 3 masters and 3 workers on a KVM hosts running Red Hat Enterprise Linux (RHEL) 
![](https://i.imgur.com/n8TQAyB.png)


## Prerequisites

Refer to the [Getting Started Guide](README.md) to ensure RHEL 7 is installed.

### Get Subscriptions

-  Get a Red Hat OpenShift Container Platform (OCP) [60-day evalution subscription](https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG).

### OCP4 Pull Secret and RHEL Qcow Image

The installer requires the latest rhel qcow image and your ocp4 pull secret. You can either download these files or provide the respective tokens and the installer will download these files for you.

#### Getting the RHEL Qcow Image
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

#### Getting the OpenShift Pull Secret
<table>
  <tr>
   <td>Using Token
   </td>
   <td>Downloading
   </td>
  </tr>
  <tr>
   <td>Navigate to <a href="https://cloud.redhat.com/openshift/token">OpenShift Cluster Manager API Token</a> to generate a token and save it as <strong>ocp_token</strong>. This token will be used to download your pull secret. 
   </td>
   <td>From your web browser, navigate to <a href="https://cloud.redhat.com/openshift/install/metal/user-provisioned">Red Hat OpenShift Cluster Manager</a>. Find the <strong>Pull secret</strong> heading to either download or copy your pull secret, save it as <strong>pull-secret.txt</strong>.
   </td>
  </tr>
</table>


## Install OpenShift

### The qubinode-installer

Downlaod and extract the qubinode-installer as a non root user.

```shell=
cd $HOME
wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
unzip master.zip
rm master.zip
mv qubinode-installer-master qubinode-installer
```

Place your pull secret and the rhel qcow image under the qubinode-installer directory. 

If you are using tokens it should be:
```
* $HOME/qubinode-installer/ocp_token
* $HOME/qubinode-installer/rhsm_token
```

If you downloaded the files instead it should be:
```
* $HOME/qubinode-installer/pull-secret.txt
* $HOME/qubinode-installer/rhel-server-7.8-x86_64-kvm.qcow2
```

### Install Options  

Choose one of the below options. The quick start is ideal if you meet your resource requirements documented in our [hardware guide](docs/hardwareguide.md). The advanced option will provide the most flexibilty as you can decide which modules you want to execute and also customize your OCP4 cluster size.

| [Quick Start](ocp4_quickstart.md) | [Advanced Installation](ocp4_adv_install.md) |
| -------- | -------- |
| Answer questions from the installer to complete installation of OpenShift 4.x.      | Step through the different Qubinode modules to complete installation.    |
