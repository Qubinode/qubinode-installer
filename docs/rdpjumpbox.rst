Jumpbox Deployments
=====================
This doc will show how to deploy a CentOS jumpbox.

Centos deployment on Qubinode
------------------------------
For Quick install::

    cd ~/qubinode-installer
    ./qubinode-installer -m setup
    ./qubinode-installer -m rhsm
    ./qubinode-installer -m ansible
    ./qubinode-installer -m host
    ./qubinode-installer -p kcli
    ./qubinode-installer -p gozones


ZTP JUMPBOX
----------------------------
.. note::
    
    https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable

Create ZTP Jumpbox::

    sudo kcli create vm -p ztpfwjumpbox jumpbox --wait


Centos Jumpbox
----------------------------
Create Centos Jumpbox::

    sudo kcli create vm -p centosjumpbox jumpbox --wait

RHEL Jumpbox
----------------------------
RHEL Jumpbox::

    sudo kcli create vm -p rhel8_jumpbox jumpbox --wait


ScreenShots
----------------------------
.. image:: https://i.imgur.com/qc7r6Eu.png
   :width: 600

.. image:: https://i.imgur.com/MeHNdGE.png
   :width: 600


Collect Ip address of jumpbox
-------------------------------
use RDP or Remmina to access Desktop::

    sudo kcli info vm jumpbox
    sudo kcli ssh jumpbox


Delete Jumpbox
------------------
delete jumpbox::

    sudo kcli delete vm jumpbox
