
=============
Quick Start
=============

Getting Started
===============

The first step is to get RHEL 9 based operating system installed on your hardware

Suppoted Operating  Systems
========================

`Fedora 37 <https://getfedora.org/>`_
---------
Make sure the following packages are installed on your system before startng the install::

    sudo dnf install git vim unzip wget bind-utils python3-pip tar util-linux-user -y

`CentOS 9 Streams <https://www.centos.org/>`_
---------

Make sure the following packages are installed on your system before startng the install::

    sudo dnf install git vim unzip wget bind-utils python3-pip tar util-linux-user -y

If you are using RHEL you can follow the steps below to get started.:

    Get Subscriptions
    -----------------
    -  Get your `No-cost developer subscription <https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux>`_ for RHEL.
    -  Get a Red Hat OpenShift Container Platform (OCP) `60-day evalution subscription <https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG>`_.

`Red Hat Enterprise Linux 9 <https://developers.redhat.com/products/rhel/hello-world>`_
---------

Make sure the following packages are installed on your system before startng the install on RHEL 9::

    curl -OL https://gist.githubusercontent.com/tosin2013/695835751174d725ac196582f3822137/raw/de9534504434d07f0d85db6f352e72c32d397890/configure-rhel9.x.sh
    chmod +x configure-rhel9.x.sh
    ./configure-rhel9.x.sh

`Red Hat Enterprise Linux 8 <https://developers.redhat.com/products/rhel/hello-world>`_
---------

Make sure the following packages are installed on your system before startng the install on RHEL 8::

    curl -OL https://gist.githubusercontent.com/tosin2013/ae925297c1a257a1b9ac8157bcc81f31/raw/71a798d427a016bbddcc374f40e9a4e6fd2d3f25/configure-rhel8.x.sh
    chmod +x configure-rhel8.x.sh
    ./configure-rhel8.x.sh


The qubinode-installer
=========================

Download and extract the qubinode-installer as a non root user::

    cd $HOME
    wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
    unzip master.zip
    rm master.zip
    mv qubinode-installer-master qubinode-installer

If you would like to develop the qubinode-installer you can clone the repo::

    YOUR_ID=githubid
    git clone https://github.com/${YOUR_ID}/qubinode-installer.git
    cd  qubinode-installer

Qubinode Setup
===============

The below commands ensure your system is setup as a KVM host.
The qubinode-installer needs to run as a regular user.

* setup   - ensure your username is setup for sudoers
* rhsm    - ensure your rhel system is registered to Red Hat
* ansible - ensure your rhel system is setup for to function as a ansible controller
* host    - ensure your rhel system is setup as a KVM host

Validate sudo user for admin::

    $ sudo cat /etc/sudoers | grep admin
      admin ALL=(ALL) NOPASSWD: ALL 
    
    $ sudo su - root
    $ curl -OL https://gist.githubusercontent.com/tosin2013/385054f345ff7129df6167631156fa2a/raw/b67866c8d0ec220c393ea83d2c7056f33c472e65/configure-sudo-user.sh
    $ chmod +x configure-sudo-user.sh
    $ ./configure-sudo-user.sh admin 
    $ sudo su - admin 


Start The Qubinode Installer::

    cd ~/qubinode-installer
    ./qubinode-installer -m setup
    ./qubinode-installer -m rhsm
    ./qubinode-installer -m ansible
    ./qubinode-installer -m host


At this point you should be able to acces the RHEL system via the cockpit web interface on
* https://SERVER_IP:9090


See the `Qubinode Overview <https://qubinode-installer.readthedocs.io/en/latest/index.html>`_ for more information on the diffent deployment options available.