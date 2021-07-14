# What is Qubinode Installer?
Qubinode-installer is an utility tool that facilates the quick deployment of an array of Red Hat products on a single piece of hardware by leveraging the [KVM](https://www.linux-kvm.org/page/Main_Page) hypervisor.

The Qubinode utility deploys the following Red Hat products:
* [Red Hat Openshift Container Platform](https://www.openshift.com/)
* [Red Hat Identity Manager](https://developers.redhat.com/blog/2016/04/29/red-hat-identity-manager-part-1-overview-and-getting-started#:~:text=Red%20Hat%20Identity%20Manager%20(IdM,%22Active%20Directory%20for%20Linux%22.)
* [Red Hat Satellite](https://www.redhat.com/en/technologies/management/satellite)

# The benefits of using qubinode
Qubinode provides a very cost effective way to quickly stand up a lab environment on a single piece of hardware. Your only cost would only be the procurement of the hardare itself. This is a cheaper approach than having to pay a license fee to use a type 1 hypervisor like VMWare/VSphere or having to pay a fee to use AWS EC2 instances.

## Motivation
The primary focus of this project is make it easy for you to deploy an OpenShift cluster on a single bare metal node with production like characteristics.

## What is OpenShift?
Red Hat OpenShift Container Platform (OCP) - is Red Hat's private platform as a service product, built around a core of application containers powered by Kubernetes and on the foundations of Red Hat Enterprise Linux.

## Resource requirements for OpenShift cluster

**Baremetal Hardware**
* At least 32 GiB of memory, 128 GiB is recommended.
* At least 300 GiB SSD or NVME dedicated storage, 1TB is recomneded.

The qubinode-installer can deploy a 3 node cluster on a system with 32GiB memory.
For the best possible experince 128 GiB of memory is recommended. This will allow
for the default deployment of a cluster with 3 controlplane and 3 computes.

**Software**
* Red Hat Enteprise Linux 8.3 installed 
Refer to the _[hardware recommendation for lab hardware suggestions](docs/qubinode/hardwareguide.md)_.
The required base OS is Red Hat Enterprise Linux 7.8 refer to the [Getting Started Guide](docs/README.md)

## Qubinode Release Information

| Qubinode Version  | Ansible version | Tag |
| ------------- | ----------------- |-----------------|
|     Release 2.4.5     | 2.9               | 2.4.5 |

### Features in v2.4.5 Versionss

New Features |
-- |
RHEL rhel-8.3-update-2-x86_64-kvm.qcow2 support |
RHEL 8.3 Default support |
OpenShift 4.7.x |
OKD 4.7.0-0.okd-2021-02-25-144700 Support |
Added Support for [jig](https://github.com/kenmoini/jig) |
Force Static IP on IDM server |
OCS Support on OpenShift 4.7.x |
Ability to change OpenShift Versions on install |


See [Release Document](docs/qubinode/releases.md) for features history.

## Deploying a OpenShift cluster

- [Installing OpenShift 4](docs/qubinode/openshift4_installation_steps.md)
- [Installing OKD 4](docs/qubinode/okd4_installation_steps.md)

**Workloads**
- [Application Workloads to try](docs/qubinode/workloads/README.md)

**Qubinode Documentation**
- [Qubinode Overview](docs/README.md)

## Training
* [Qubinode for Beginners](docs/beginners.md)
* [learn.openshift.com](https://learn.openshift.com/)

**Red Hat Courses**

_OpenShift_
* [Introduction to Containers, Kubernetes, and Red Hat OpenShift](https://www.redhat.com/en/services/training/do180-introduction-containers-kubernetes-red-hat-openshift)
* [Red Hat OpenShift Administration I (DO280)](https://www.redhat.com/en/services/training/do280-red-hat-openshift-administration-i)
* [Red Hat OpenShift Administration II (DO380)](https://www.redhat.com/en/services/training/do380-red-hat-openshift-administration-ii-high-availability)

_Ansible_
- [Ansible Essentials: Free Technical Overview (low-level introduction)](https://www.redhat.com/en/services/training/do007-ansible-essentials-simplicity-automation-technical-overview)
- [(RH294) Linux Automation with Ansible](https://www.redhat.com/en/services/training/rh294-red-hat-system-administration-iii-linux-automation)

## Contribute
* [Communications](docs/qubinode/communication.md)


If you would like to Contribute to the qubinode project please see the documentation below.  
* [Qubinode WorkFlow Process](docs/CONTRIBUTING.md)  
* [Testing and Validation](test/README.md)  

## Support
If you have any direct questions, reach out to us [using the guide](docs/communication.md).

## Known issues

## Qubinode Dev Branch for next release
Feature  |  Status
--|---
Red Hat Satellite Server  | In progress
CNV Support | Dev
Disconnected Instaltion | Dev  
Cockpit Integration | In progress

## Roadmap
* CNV Installation 
* Disconnected Installaton
* Multinode Depolyment
* Libvirt with KVM  OCP - (Experimental)
* OpenWrt Router Support - (Experimental

## Contributions
We value community and collaboration, therefore any contribution back to the project/community is always welcome. 

## Ways to contribute
We kindly ask you to open an issue if you find anything wrong and or something that can be improved during your usage of qubinode. If it's something that you're able to fix, please fork the project, apply your fix and submit a merge request, then we'll review and approve your merge request. Thank you for using qubinode we're looking forward to your contribution back to the project.

## Acknowledgments
* [bertvv](https://github.com/bertvv)
* [karlmdavis](https://github.com/karlmdavis)
* [Jooho](https://github.com/Jooho)

## Authors
* Tosin Akinosho - [tosin2013](https://github.com/tosin2013)
* Rodrique Heron - [flyemsafe](https://github.com/flyemsafe)
* Abnerson Malivert - [amalivert](https://github.com/amalivert)
