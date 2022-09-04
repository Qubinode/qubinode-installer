
=============
Quick Start
=============

Getting Started
=====

The first step is to get RHEL installed on your hardware

Get Subscriptions
=====
-  Get your `No-cost developer subscription <https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux>`_ for RHEL.
-  Get a Red Hat OpenShift Container Platform (OCP) `60-day evalution subscription <https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG>`_.

Install Red Hat Enterprise Linux
=====
A bare metal system running Red Hat Enterprise Linux 8. Follow the `RHEL Installation Walkthrough <https://developers.redhat.com/products/rhel/hello-world#fndtn-rhel>`_ to get RHEL installed on your hardware. When installing RHEL, for the software selection, **Base Environment** choose one of the following:

1. Virtualization Host
2. Server with GUI

If you choose **Server with GUI**, make sure from the **Add-ons for Selected Evironment** you select the following:

- Virtualization Hypervisor 
- Virtualization Tools

**_TIPS_**
> * If using the recommend storage of one ssd and one NVME, install RHEL on the ssd, not the NVME. 
>  * The RHEL installer will delicate the majority of your storage to /home,  you can choose **"I will configure partitioning"** to have control over this.
>  * Set root password and create admin user with sudo privilege

The qubinode-installer
=====

Download and extract the qubinode-installer as a non root user::

    cd $HOME
    wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
    unzip master.zip
    rm master.zip
    mv qubinode-installer-master qubinode-installer


Qubinode Setup
=====

The below commands ensure your system is setup as a KVM host.
The qubinode-installer needs to run as a regular user.

* setup   - ensure your username is setup for sudoers
* rhsm    - ensure your rhel system is registered to Red Hat
* ansible - ensure your rhel system is setup for to function as a ansible controller
* host    - ensure your rhel system is setup as a KVM host

> Go [here](qubinode/qubinode-menu-options.adoc) for additional qubinode options.

Validate sudo user for admin::

    $ sudo cat /etc/sudoers | grep admin
    $ admin ALL=(ALL) NOPASSWD: ALL 
    $ echo "admin ALL=(ALL) NOPASSWD: ALL" | tee -a  /etc/sudoers


Start The Qubinode Installer::

    cd ~/qubinode-installer
    ./qubinode-installer -m setup
    ./qubinode-installer -m rhsm
    ./qubinode-installer -m ansible
    ./qubinode-installer -m host


At this point you should be able to acces the RHEL system via the cockpit web interface on
* https://SERVER_IP:9090

Deploy a Red Hat Product
=====
Most products depends on the latest rhel 8 or 9 qcow image. You can either manually download them or provide your RHSM api token and the installer will download these files for you.

Getting the RHEL 7 or 8 Qcow Image
----------------------------------

.. list-table:: Title
   :widths: 50 50 
   :header-rows: 1

    - Heading Using Token , Download
    - Row Navigate to <a href="https://access.redhat.com/management/api">RHSM API</a> to generate a token and save it as <strong>rhsm_token</strong>. This token will be used to download the rhel qcow image. , From your web browser, navigate to <a href="https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software">Download Red Hat Enterprise Linux</a>. Download the qcow image matching this checksum the below checksum.   


Follow the same steps to get the RHEL 8 qcow image.

If you are using tokens it should be:: 

    * $HOME/qubinode-installer/rhsm_token


If you downloaded the files instead, confirm that the project directory list the qcow images below or later versions::

    * $HOME/qubinode-installer/rhel-8.5-update-2-x86_64-kvm.qcow2
    * $HOME/qubinode-installer/rhel-8.5-update-2-x86_64-kvm.qcow2