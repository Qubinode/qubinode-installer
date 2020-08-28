# Qubinode Installer
Qubinode is for users wanting to stand up an RHEL based lab environment running on KVM.

## Motivation
The primary focus of this project is make it easy for you to deploy a OpenShift cluster on a single bare metal node with production like characteristics.

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
* Red Hat Enteprise Linux 8.2 installed (Recommended)
* or Red Hat Enteprise Linux 7.8 installed
Refer to the _[hardware recommendation for lab hardware suggestions](docs/qubinode/hardwareguide.md)_.
The required base OS is Red Hat Enterprise Linux 7.8 refer to the [Getting Started Guide](docs/README.md)

## Qubinode Release Information

| Qubinode Version  | Ansible version | Tag |
| ------------- | ----------------- |-----------------|
|     Release 2.4.3     | 2.9               |  |

### Features in v2.4.3 DEV Version

New Features |
-- |
NFS Server fixes |
NFS Server is installed by default |


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
Red Hat Satellite Server  | In progress|
OCS Support |  In progress  |   
Cockpit Integration | In progress

## Roadmap
* OCP 4.x Container Native Storage
* Libvirt with KVM  OCP - (Experimental)
* OpenWrt Router Support - (Experimental)

## Acknowledgments
* [bertvv](https://github.com/bertvv)
* [karlmdavis](https://github.com/karlmdavis)
* [Jooho](https://github.com/Jooho)

## Authors
* Tosin Akinosho - [tosin2013](https://github.com/tosin2013)
* Rodrique Heron - [flyemsafe](https://github.com/flyemsafe)
* Abnerson Malivert - [amalivert](https://github.com/amalivert)
