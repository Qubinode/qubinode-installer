# OpenShift 4.x Cluster Deployment Quick start

Please refer to [Installing an OpenShift 4.x Cluster on a Single Node](openshift4_installation_steps.md) before continuing here.

```shell=
cd $HOME/qubinode-installer
./qubinode-installer
```

*Select Option 1: Continue with the default installation*

![](https://i.imgur.com/6UmK2Gd.png)

**This will perform the following**
* Configure server for KVM.
* Deploy an idm server to be used as DNS.
* Deploy OpenShift 4.
* Optional: Configure NFS Provisioner

## Adavanced Flags 
[Additional options](qubinode/ocp4_adv_install.md)

## Deployment Post Steps

How to access OpenShift Cluster
* Option 1: Add dns server to /etc/resolv.conf on your computer.
  - Or run script found under lib/qubinode_dns_configurator.sh
* Option 2: Add dns server to router so all machines can access the OpenShift Cluster.
