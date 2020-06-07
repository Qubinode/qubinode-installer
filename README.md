# Qubinode Installer
Qubinode is a single baremetal node OpenShift cluster powered by Red Hat’s suite of hybrid cloud technologies.


## Features in v2.4 RC Version

New Features |
-- |
OpenShift 4.4.x |
OpenShift 4 Ansible Role  |
NFS Provisioner Role |
Ansible 2.9 Compatibility  |
local storage support  |
Custom VM support  |
OCP4 Cluster Shutdown |
OCP4 Cluster Startup |
OCP4 Cluster Verification  |

## Qubinode Dev Branch for next release

Feature  |  Status
--|---
Ansible Tower | In progress |  
Red Hat Satellite Server  | In progress|
RHEL 8.x Support  | In progress|
OKD 4.x Support  | In Development |
OCS Support |  In progress  |   |


## Motivation
Qubinode is for users wanting to stand up an OpenShift cluster in a secure and controlled environment with the flexibility to carry the cluster wherever you want. It is intended for those who need to simulate as close as possible a production type OpenShift cluster on a single bare metal node.

## What is OpenShift?
* Red Hat OpenShift Container Platform (OCP) - is Red Hat's private platform as a service product, built around a core of application containers powered by Kubernetes and on the foundations of Red Hat Enterprise Linux.
* OKD - The Origin Community Distribution of Kubernetes that powers Red Hat OpenShift.

**The installer supports installing (OCP) or (OKD)**
 - Current state is the installer primarly supports deploying OKD 3.11.x, OCP 3.11.x, and OCP4 4.3 builds. Installing OCP3 or OCP4 will require a Red Hat subscription.

## Requirements

**Baremetal Hardware**
* At least 32 GB of memory, 128 GB is recommended.
* At least 300 GB SSD or NVME dedicated storage, 1TB is recomneded.

_[Recommend Hardware](docs/qubinode/hardwareguide.md)_

**Software**
* Red Hat Enteprise Linux 7.7 installed

**Subscriptions**

_Required_
* Red Hat Enteprise Linux [no-cost Red Hat Enterprise Linux Developer Subscription](https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux/).

_Optional_
* For deploying Red Hat OpenShift Container Platform (OCP) you can obtain a [60-day evalution subscription](https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG).

## Installation Guide

We continue to improve our documentation and would like to hear from you on how to make it better.You may contact us [here](docs/communication.md).
- [Installing OpenShift 4](docs/qubinode/openshift4_installation_steps.md)
- [Red Hat Enterprise Linux VM Deployment](docs/qubinode/rhel_vms.md)

**Workloads**
- [Application Workloads to try](docs/qubinode/workloads/README.md)

## Qubinode Release Information

| Qubinode Version  | Ansible version | Tag |
| ------------- | ----------------- |-----------------|
|     Release 2.4     | 2.9               | 2.4 |


## Training
* [Qubinode for Beginners](docs/qubinode/beginners.md)
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
* [Qubinode WorkFlow Process](docs/qubinode/qubinode_git_branching_model.md)  
* [Testing and Validation](test/README.md)  

## Support
If you need support, start with [the troubleshooting guide](docs/qubinode/troubleshooting-monitoring.md)

If you have any direct questions, reach out to us [using the guide](docs/qubinode/communication.md).

## Known issues

## Roadmap
* OCP 4.x Container Native Storage
* OCP 4.x on RHEV
* Libvirt with KVM  OCP- (Experimental)
* OpenWrt Router Support - (Experimental)

## Acknowledgments
* [bertvv](https://github.com/bertvv)
* [karlmdavis](https://github.com/karlmdavis)
* [Jooho](https://github.com/Jooho)

## Authors
* Tosin Akinosho - [tosin2013](https://github.com/tosin2013)
* Rodrique Heron - [flyemsafe](https://github.com/flyemsafe)
* Abnerson Malivert - [amalivert](https://github.com/amalivert)
