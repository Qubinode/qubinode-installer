# Qubinode Release history 

## List of Qubinode Features by Release

### Release web page
https://github.com/Qubinode/qubinode-installer/releases


**Qubinode v2.4.6 Release notes**
* RHEL 8.4 default support 
* RHEL rhel-8.4-x86_64-kvm.qcow2 support
* external baremetal deployment
* OCS Storage fixes 
  * Using OCS pvc for registry pvc
* Fixes for external network deployments
* adding support for kcli
* Adding Fixes for Anisble Tower Deployment


**Qubinode v2.4.5 Release notes**
* OCS Support on OpenShift 4.7.x
* Ability to change OpenShift Versions on install


**Qubinode v2.4.4 Release notes**
* RHEL rhel-8.3-update-2-x86_64-kvm.qcow2 support 
* RHEL 8.3 Default support
* OpenShift 4.7.x
* OKD 4.7.0-0.okd-2021-02-25-144700
* Added Support for [jig](https://github.com/kenmoini/jig)
* Force Static IP on IDM server

**Qubinode v2.4.3 Release notes**
* OpenShift 4.6.x
* Code improvements to speed up the deployment of OpenShift
* Deploy the [Kubernetes NFS-Client Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) by default
* Configures the Qubinode as a NFS server
* Set up the OpenShift registry to use NFC PVC

**Qubinode v2.4.3 Release notes**
* OpenShift 4.6.x support
* fix IDM Bugs
* Local Storage Option Recommend deployment option
* External Bridge Deployment Support for OpenShift Nodes

**Qubinode v2.4.2 Release notes**
* fixed NFS server bug adding nfs server mount to the correct location `/home/nfs_mount/data`
* adding NFS Server as default for remote storage


**Qubinode v2.4.2 Release notes**
* RHEL 8.2 Support
* OpenShift sizing menu fixes
* OpenShift 4.4.x
* OpenShift 4.5.x (Optional)
* OKD 4 menu Option
* Ansible 2.9 Compatibility
* local storage support mutliple disk support
* Fixed IDM bugs
* Ansible Tower Support

**Qubinode v2.4.2 Release notes**
* RHEL 8.2 Support
* OpenShift sizing menu fixes
* OpenShift 4.4.x
* OpenShift 4.5.x (Optional)
* OKD 4 menu Option
* Ansible 2.9 Compatibility
* local storage support mutliple disk support
* Fixed IDM bugs
* Ansible Tower Support

**Qubinode 2.4.1 Release notes**
* Move qubinode install options doc to qubinode/doc
* Add link for main documentation to the qubinode install options
* Fix search for existing qcow image
* Fix issues with ping and dns lookup for the idm server
* Fix issue #230

**Qubinode 2.4.0 Release notes**

* Documentation improvements
* Support for deploying generic RHEL vms
* Support for NFS and Local Storage
* Support for deploying 3 node cluster, each node with the role of master/worker
* Support for deploying 4 node cluster, 3 masters and 1 worker
* Support for customizing the cluster deployment, vcpu, memroy, storage and number of workers
