# Qubinode Installer
Qubinode is a single node OpenShift cluster powered by Red Hat’s suite of hybrid cloud technologies.

## POST RELEASE TEST BRANCH
[releasev2.2](https://github.com/Qubinode/qubinode-installer/tree/releasev2.2) testing branch.  

If you would like to Contribute to the qubinode project please see the documentation below.  
[Qubinode WorkFlow Process](docs/git-workflow-process.adoc)  
[Testing and Validation](test/README.md)  

## Motivation
Qubinode is for users wanting to stand up an OpenShift cluster in a secure and controlled environment with the flexibility to carry the cluster wherever you want. It is intended for those who need to simulate as close as possible a production type OpenShift cluster on a single bare metal node.

## What is OpenShift?
* OCP - is Red Hat's on-premises private platform as a service product, built around a core of application containers powered by Docker, with orchestration and management provided by Kubernetes, on a foundation of Red Hat Enterprise Linux.
* OKD - The Origin Community Distribution of Kubernetes that powers Red Hat OpenShift.

The installer supports installing Red Hat OpenShift (OCP) or The Origin Community Distribution of Kubernetes (OKD).
 - Current state is support only exist for OKD3. Installing OCP3 or OCP4 will require a Red Hat subscription.
 - Installing OCP3 or OCP4 will requires a Red Hat OpenShift subscription. Please contact Red Hat slaes.
 - The base OS is RHEL. If you are installing OKD3 you can take advantage of the no-cost RHEL subscription available at developers.redhat.com.

## Requirements
* Server with at least 64 GB Memory
* Server With at least 1 TB of Secondary Hard Drive
* Ansible version 2.6 and up
* RHEL7
* For [OpenShift Enterprise](https://www.openshift.com/products) (OCP)  a subscription is needed with Red Hat.  
* For [OpenShift Origin](https://www.okd.io/) (OKD) a subscription is not needed.

## Supported Versions
The Qubinode installer currently supports OpenShift 3.11.x and 4.2 builds.

## Recommended Hardware
[Supported Hardware](docs/supported_hardware_coniguration.md)

## OpenShift Architecture

## Installation

We are working as best we can to have better documentation. Contributions are welcome.

- [Installing OpenShift 4](docs/openshift4_installation_steps.md)
- [Installing OpenShift 3](docs/openshift3_installation_steps.adoc)

## Day Two Operations

## Training

## Contribute
[Communications](docs/communication.adoc)

## Support
If you need support, start with [the troubleshooting guide](docs/troubleshooting-monitoring.adoc)

If you have any direct questions, reach out to us [using the guide](docs/communication.adoc).

## Known issues

## Roadmap
* OCP 4.x Container Native Storage
* OCP 4.x and RHEV

## Acknowledgments
* [bertvv](https://github.com/bertvv)
* [karlmdavis](https://github.com/karlmdavis)
* [Jooho](https://github.com/Jooho)

## Author
Tosin Akinosho - [tosin2013](https://github.com/tosin2013)  
Rodrique Heron - [flyemsafe](https://github.com/flyemsafe)  
Abnerson Malivert - [amalivert](https://github.com/amalivert)  
