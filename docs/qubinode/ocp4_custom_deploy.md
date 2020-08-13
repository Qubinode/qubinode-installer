# OpenShift 4.x Custom Deployment

All custom cluster deployment options defaults to 3 ControlPlane nodes.
A cluster with 3 nodes is smallest cluster deployment size
supported by the OCP4 installer. When deploying 3 nodes only, each node
gets assigned the role of compute and controlplane. Each cluster is deployed
with NFS for persistent storage.

1. **Minimal Cluster Deployment Options**

    Two options are available for systems with less than 128 Gib memory:
      * A 3 node controlplane/compute cluster for systems with only 32 Gib memory
      * A 4 node cluster, 3 controlplane and 1 compute for systems with 64 Gib memory

    A minimum of 6 cores is recommended. The 3 node option deploys each node
    with 10 Gib memory and 4 vCPUs. The 4 node option deploys each node with
    12 Gib memory and 4 vCPUs.

2. **Standard and Custom Cluster Deployment Options**
  
    Three options are available for systems with more than 128 Gib memory:
    * A 5 node cluster 3 controlplane and 2 computes
    * A 6 node cluster 3 controlplane and 2 computes with the option for local storage
    * A custom option to increase the number of computes and memory, vpcu, storage size for each node

## 4.4.15 is deployed by default to change see below 
*  4.4.15 deployed by default
* Optional Deploy 4.5.5
```
# Update the following file and variables before deployment
vim samples/ocp4.yml
ocp4_release: 4.5.5
ocp4_image: 4.5.2

```

## Deploy the cluster

Please refer to [Installing an OpenShift 4.x Cluster on a Single Node](openshift4_installation_steps.md) before continuing with this install.

Start the installation with the below command. The installation will run then present you menu to choose from.

```=shell
cd $HOME/qubinode-installer
./qubinode-installer -p ocp4
```

The menu options.
```
      1. Minimal 3 node cluster
      2. Minimal 4 node cluster
      3. Standard 5 node cluster
      4. Standard 6 node cluster with local storage
      5. Custom Deployment
      6. Exit


   Enter choice [ 1 - 6] 6
```

## Deployment Post Steps
* [LDAP OpenShift configuration](openshift_ldap_config.md)

Accessing the cluster web console.

* Option 1: Add dns server to /etc/resolv.conf on your computer.
  - Or run script found under lib/qubinode_dns_configurator.sh
* Option 2: Add dns server to router so all machines can access the OpenShift Cluster.

**Additional cluster operations commands are avialable [here](ocp4_cluster_ops.md)**  

## Troubleshooting Guide
[Troubleshooting installation](troubleshooting-monitoring.md)