# Qubinode Installer
Qubinode is a single node OpenShift cluster powered by Red Hat’s suite of hybrid cloud technologies.

## Motivation
Qubinode is for users wanting to stand up an OpenShift cluster in a secure and controlled environment with the flexibility to carry the cluster wherever you want. It is intended for those who need to test OpenShift in a private setting where data security is top of mind. Qubinode..

## What is OpenShift?
* OCP - is Red Hat's on-premises private platform as a service product, built around a core of application containers powered by Docker, with orchestration and management provided by Kubernetes, on a foundation of Red Hat Enterprise Linux.
* OKD - The Origin Community Distribution of Kubernetes that powers Red Hat OpenShift.

The installer supports installing Red Hat OpenShift  (OCP) or The Origin Community Distribution of Kubernetes (OKD).  The OCP installation requires an OCP subscription. The OKD installation will require Red Hat Enterprise Linux (RHEL) subscription only. To obtain a OCP subscription please contact Red Hat sales. To obtain a RHEL subscription please  visit developers.redhat.com.

## Requirements
* Server with at least 64 GB Memory
* Server With at least 1 TB of Secondary Hard Drive
* Ansible version 2.6 and up
* RHEL7
* For [OpenShift Enterprise](https://www.openshift.com/products) (OCP)  a subscription is needed with Red Hat.  
* For [OpenShift Origin](https://www.okd.io/) (OKD) a subscription is not needed.

## Supported Versions
The Qubinode installer currently supports OpenShift 3.11.x builds.

## In Development
* OCP 4.2 installation
  - [Install instructions](https://gist.github.com/tosin2013/479acd3ca676aec6f42514f7df2f8921)
  - Testing and contributions are welcome

## Recommended Hardware
[Supported Hardware](docs/supported_hardware_coniguration.md)

## Quick start
```
wget https://github.com/tosin2013/qubinode-installer/archive/master.zip
unzip master.zip
mv qubinode-installer-master quibinode-installer
rm -f master.zip
cd quibinode-installer
./quibinode-installer
```

## Qubinode Installer Menu
```
[admin@qubinode qubinode-installer]$ ./qubinode-installer


    The default product option is to install Red Hat Openshift Container Platform (OCP).
    An subscription for OCP is required. If you do not have an OCP subscription. Please
    display the menu options for other product installation such as OKD.

    The OCP cluster deployment consist of:

      - 1 IDM server for DNS
      - 1 Master node
      - 2 App nodes
      - 2 Infra nodes

    Gluster is deployed as the container storage running on the infra and app nodes.

    If you wish to continue with this install choose the **continue** option otherwise
    display the help menu to see the available options.
1) Continue with the default installation - OCP OpenShift Enterprise
2) OKD - The Origin Community Distribution of Kubernetes
3) IDM - Red Hat Identity Manager Install
4) KVM - Configure your machine to run KVM
5) Display the help menu
#?

```

## Installation
[Installing The Qubinode](docs/installation_draft.md)

## Deployment Architecture

## Architecture

## Contribute
[Communications](docs/communication.adoc)

## Support
If you need support, start with [the troubleshooting guide](docs/troubleshooting-monitoring.adoc)

If you have any direct questions, reach out to us [using the guide](docs/communication.adoc).

## Known issues
* DNS server fails to get IP on first deployment
```
# run the following
./qubinode_installer -p idm -d
rerun qubinode_installer or ./qubinode_installer -p idm
```

* OpenShift VM fails to get ip on first depoyment
```
# run the following
# for OpenShift Enterprise
./qubinode_installer -p ocp -d
rerun qubinode_installer Option 1 or
./qubinode_installer -p ocp -m deploy_nodes and ./qubinode_installer -p ocp

# for OpenShift Origin
./qubinode_installer -p okd -d
rerun qubinode_installer Option 2 or
./qubinode_installer -p okd -m deploy_nodes and ./qubinode_installer -p okd
```

## Roadmap
* OCP 4.2
* OCP 4.2 Container Native Storage
* OCP 4.3 and RHEV

## Acknowledgments
* [bertvv](https://github.com/bertvv)
* [karlmdavis](https://github.com/karlmdavis)
* [Jooho](https://github.com/Jooho)

## Author
Tosin Akinosho - [tosin2013](https://github.com/tosin2013)  
Rodrique Heron - [flyemsafe](https://github.com/flyemsafe)  
Abnerson Malivert - [amalivert](https://github.com/amalivert)  
