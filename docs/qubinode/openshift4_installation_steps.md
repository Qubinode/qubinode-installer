#  Installing an OpenShift 4.x Cluster on a Single Node

The following documentation will help you deploy an OpenShift Container Platform (OCP) 4.3 cluster, on a single node.
The installation steps deploys a production like OCP4 cluster, in a environment with 3 controlplane and 3 computes on a KVM hosts running Red Hat Enterprise Linux (RHEL)
![](https://i.imgur.com/n8TQAyB.png)

## Prerequisites

Refer to the [Getting Started Guide](../README.md) to ensure RHEL 7 is installed.

### Get Subscriptions

-  Get a Red Hat OpenShift Container Platform (OCP) [60-day evalution subscription](https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG).

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

Download and extract the qubinode-installer as a non root user.

```shell=
cd $HOME
wget https://github.com/Qubinode/qubinode-installer/archive/main.zip
unzip main.zip
rm main.zip
mv qubinode-installer-main qubinode-installer
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

Choose one of the below options. The quick start is ideal if you meet your resource requirements documented in our [hardware guide](hardwareguide.md). The advanced option will provide the most flexibilty as you can decide which modules you want to execute and also customize your OCP4 cluster size.

| [Standard Deployment](ocp4_standard_deploy.md) | [Custom Deployment](ocp4_custom_deploy.md) |
| -------- | -------- |
| Answer questions from the installer to deploy a 6 node OpenShift 4.x cluster, 3 controlplane and 3 computes.| This option will allow you to deploy a 3 only or 4 node cluster or to customize the size of the cluster.|

### Additional Documentation

* [Qubinode OpenShift Cluster Operations](ocp4_cluster_ops.md)
* [LDAP OpenShift configuration](openshift_ldap_config.md)


### Troubleshooting Tips
[Troubleshooting installation](troubleshooting-monitoring.md)
