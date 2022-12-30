
=============
Quick Start
=============

Getting Started
===============

The first step is to get RHEL 9 based operating system installed on your hardware

Suppoted Operating  Systems
========================
Fedora 37
---------
- `Fedora 37 <https://getfedora.org/>`_


.. Prerequisites::
          sudo dnf install git vim unzip wget bind-utils python3-pip tar util-linux-user -y

- `CentOS 9 Streams <https://www.centos.org/>`_
- `Red Hat Enterprise Linux 9 <https://developers.redhat.com/products/rhel/hello-world>`_
- `Red Hat Enterprise Linux 8 <https://developers.redhat.com/products/rhel/hello-world>`_

If you are using RHEL you can follow the steps below to get started.

Get Subscriptions
====================
-  Get your `No-cost developer subscription <https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux>`_ for RHEL.
-  Get a Red Hat OpenShift Container Platform (OCP) `60-day evalution subscription <https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG>`_.

The qubinode-installer
=========================

Download and extract the qubinode-installer as a non root user::

    cd $HOME
    wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
    unzip master.zip
    rm master.zip
    mv qubinode-installer-master qubinode-installer


Qubinode Setup
===============

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


See the `Qubinode Overview <https://qubinode-installer.readthedocs.io/en/latest/index.html>`_ for more information on the diffent deployment options available.