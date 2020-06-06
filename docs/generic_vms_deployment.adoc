= Installing The Qubinode
Rodrique Heron <rheron@rodhouse.org>
v0.0, 2019-08-25
:imagesdir: images
:toc: preamble
:homepage: https://github.com/Qubinode/qubinode-installer

This guide should get you up and running with qubinode.

:numbered!:
[abstract]
= Introduction


The qubinode can be used to deploy Generic sms supported vm deployments at this time are Red Hat 7 and Red Hat 8. Other operating systems can be used from the cockpit ui. If you would  like to Contriube code for other operating system types plese do using the following link:docs/qubinode_git_branching_model.adoc[guide].

== Prerequisites

=== Get Subscriptions

-  Get your link:https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux/[No-cost developer subscription] for RHEL.

==== Getting the RHEL Qcow Image
.Table Getting the RHEL Qcow Image
|===
|Using Token | Downloading

|Navigate to link:https://access.redhat.com/management/api[RHSM API] to generate a token and save it as *rhsm_token*. This token will be used to download the rhel qcow image. 

|From your web browser, navigate to link:https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software[Download Red Hat Enterprise Linux]. Download the qcow image matching this checksum the below checksum.
|===

== Install Red Hat Enterprise Linux
A bare metal system running RHEL. Follow the link:https://developers.redhat.com/products/rhel/hello-world#fndtn-rhel[RHEL Installation Walkthrough] to get RHEL installed on your hardware. When installing RHEL, for the software selection, **Base Environment** choose one of the following:

1. Virtualization Host
2. Server with GUI

If you choose **Server with GUI**, make sure from the **Add-ons for Selected Evironment** you select the following:

- Virtualization Hypervisor 
- Virtualization Tools

*_TIPS_*  

TIP:  If using the recommend storage of one ssd and one NVME, install RHEL on the ssd, not the NVME. 

TIP:  The RHEL installer will delicate the majority of your storage to /home,  you can choose **"I will configure partitioning"** to have control over this.

TIP: Set root password and create admin user with sudo privilege

=== The qubinode-installer

Downlaod and extract the qubinode-installer as a non root user.

```shell
cd $HOME
wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
unzip master.zip
rm master.zip
mv qubinode-installer-master qubinode-installer
```

Place your pull secret and the rhel qcow image under the qubinode-installer directory. 

If you are using tokens it should be:
```
* $HOME/qubinode-installer/rhsm_token
```