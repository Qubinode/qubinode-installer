Ceph Deployment on Qubinode
================
Red Hat Ceph Storage is an open, massively scalable, highly available and resilient distributed  storage solution for modern data pipelines. Engineered for data analytics, artificial intelligence/machine learning (AI/ML), and hybrid cloud workloads, Red Hat Ceph Storage delivers software-defined storage for both containers and virtual machines on your choice of industry-standard hardware.

* `Product Documentation for Red Hat Ceph Storage 5 <https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/5>`_
* `Red Hat Ceph Storage 5: Introducing Cephadm <https://www.redhat.com/en/blog/red-hat-ceph-storage-5-introducing-cephadm>`_

Tested on
----------
* RHEL 9.1

Configure Qubinode for Ceph Deployment
------------------------------

For Quick install::

    git clone https://github.com/tosin2013/qubinode-installer.git
    cd ~/qubinode-installer
    ./qubinode-installer -m setup
    ./qubinode-installer -m rhsm
    ./qubinode-installer -m ansible
    ./qubinode-installer -m host
    ./qubinode-installer -p kcli
    ./qubinode-installer -p gozones

Create plan for Ceph Cluster Deployment
----------------------------------------

Steps:: 

    $ sudo ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
    # Option edit nets under  kcli_plans/ceph/ceph-cluster.yml
    $ sudo kcli create plan -f  kcli_plans/ceph-deployment.yml
    $ samples/scripts/update-ceph-dns.sh # press q to exit
    $ sudo kcli ssh ceph-mon01
    $ sudo su - root 
    $ journalctl -xf #wait for script to complete or check rhel8_ceph.sh script $ watch ls /tmp/
    $ /tmp/rhel8_ceph.sh


Default username and password for ceph cluster
----------------------------------------------
* Username: admin
* Password: yourgoingtohavetochangeme

Delete Plan this will delete all the VMs created by the plan
-------------------------------------------------------------

Deleting the plan will delete all the VMs created by the plan::

    kcli list plan
    +---------------+-------------------------------------------------------------------+
    | Plan          | Vms                                                               |
    +---------------+-------------------------------------------------------------------+
    | thirsty-conti | ceph-mon01,ceph-mon02,ceph-mon03,ceph-osd01,ceph-osd02,ceph-osd03 |
    +---------------+-------------------------------------------------------------------+

    kcli delete plan thirsty-conti

Qubinode Maintance commands
------------------------------
Update default settings for qubinode deployments::

    ./qubinode-installer -p kcli -m updatedefaults



