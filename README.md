## What is Qubinode Installer?
Qubinode-installer is an utility tool that facilates the quick deployment of an array of Red Hat products like [Red Hat Openshift Container Platform](https://www.openshift.com/), [Red Hat Identity Manager](https://access.redhat.com/products/identity-management#getstarted), [Red Hat Satellite](https://www.redhat.com/en/technologies/management/satellite), etc.. on a single piece of [hardware](https://mitxpc.com/products/gn-e300-9d-8tp) by leveraging the [KVM](https://www.linux-kvm.org/page/Main_Page) hypervisor.
[![Documentation Status](https://readthedocs.org/projects/qubinode-installer/badge/?version=latest)](https://qubinode-installer.readthedocs.io/en/latest/?badge=latest)

## The benefits of using qubinode
[The Qubinode Project](https://qubinode.io/) provides a very cost effective way to quickly stand up a lab environment on a single piece of [hardware](https://mitxpc.com/products/gn-e300-9d-8tp). Your most expensive investment would be the procurement of the [hardware](https://mitxpc.com/products/gn-e300-9d-8tp) itself. This is a cheaper approach than having to pay a license fee to use a type 1 [hypervisor](https://www.vmware.com/topics/glossary/content/hypervisor) like VMWare/VSphere or having to pay a fee to use AWS EC2 instances.

## Motivation
The primary focus of this project is make it easy for you to deploy an OpenShift cluster on a single bare metal node with production like characteristics. Please visit [The Qubinode Project](https://qubinode.io/) landing page for step by step easy to follow guide on how to get started.

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
* Red Hat Enteprise Linux 9.1
Refer to the _[hardware recommendation for lab hadware suggestions](docs/qubinode/hardwareguide.md).
One of the  supported base OS is Red Hat Enterprise Linux 9.0 refer to the [Getting Started Guide](https://qubinode-installer.readthedocs.io/en/latest/quick_start.html#getting-started)
* Centos 9 Streams is supported base OS.
* Fedora 37 is a supported base OS.


## Qubinode Release Information

| Qubinode Version  | Ansible version | Tag |
| ------------- | ----------------- |-----------------|
|     Release 3.0     | 2.10               | 2.8.0 |

### Testing 
* [chatgpt: Chat GPT console client in Golang](https://github.com/kkdai/chatgpt)

### Features in v3.0 Version
- [x] Support for RHEL 9.1
- [x] Support for Centos 9 Streams
- [x] Vyos Router Support 
- [x] kcli support  to manage vm deployments
- [x] Ansible Automation Platform 2.1
- [x] Red Hat Ceph Storage 5
- [x] kvm-install-vm to manage vm deployments
- [x] Support for TailScale VPN

See [Documentation for additional details](https://qubinode-installer.readthedocs.io/en/latest/).

## Deploying a OpenShift cluster
- [OpenShift Assisted Installer Service, Universal Deployer](https://qubinode-installer.readthedocs.io/en/latest/ocp4-ai-svc-universal.html)
- [OpenShift 4 Assisted Installer Service, Libvirt Deployer](https://github.com/tosin2013/ocp4-ai-svc-libvirt/tree/main/scripts)
- [Ansible Automation Platform](https://github.com/Red-Hat-SE-RTO/rhel-fleet-management/blob/main/docs/install-ansible-automation-platform.md)

**Workloads**
- [Application Workloads to try](docs/qubinode/workloads/README.md)
- [Deploy Bare-Metal Clusters via Hive and Assisted Installer](https://github.com/tosin2013/bare-metal-assisted-installer)

**Qubinode Documentation**
- [Qubinode Overview](https://qubinode-installer.readthedocs.io/en/latest/quick_start.html#getting-started)

## Training
* [Qubinode for Beginners](https://qubinode-installer.readthedocs.io/en/latest/quick_start.html#getting-started)
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
We value community and collaboration, therefore any contribution back to the project/community is always welcome. 
* [Communications](docs/qubinode/communication.md)


If you would like to Contribute to the qubinode project please see the documentation below.  
* [Qubinode WorkFlow Process](docs/CONTRIBUTING.md)  
* [Testing and Validation](test/README.md)  

## Ways to contribute
We kindly ask you to open an issue if you find anything wrong and or something that can be improved during your usage of qubinode. If it's something that you're able to fix, please fork the project, apply your fix and submit a merge request, then we'll review and approve your merge request. Thank you for using qubinode we're looking forward to your contribution back to the project.

## Support
If you have any direct questions, reach out to us [using the guide](docs/communication.md).

## Known issues

## Acknowledgments
* [bertvv](https://github.com/bertvv)
* [karlmdavis](https://github.com/karlmdavis)
* [Jooho](https://github.com/Jooho)
* [Karim Boumedhel](https://github.com/karmab)
* [Ken Moini](https://github.com/kenmoini)
* [Giovanni Torres](https://github.com/giovtorres)
  
## Authors
* Tosin Akinosho - [tosin2013](https://github.com/tosin2013)
* Rodrique Heron - [flyemsafe](https://github.com/flyemsafe)
* Abnerson Malivert - [amalivert](https://github.com/amalivert)