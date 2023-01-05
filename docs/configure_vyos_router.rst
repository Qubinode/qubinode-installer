Deploy Vyos router on Qubinode
================
VyOS is an open source network operating system based on Debian GNU/Linux.

VyOS provides a free routing platform that competes directly with other commercially available solutions from well known network providers. Because VyOS runs on standard amd64, i586 and ARM systems, it is able to be used as a router and firewall platform for cloud deployments.

* `Website <https://vyos.io/>`_
* `Docs <https://docs.vyos.io/en/latest/index.html#>`_

Tested on
----------
* Fedora 37
* RHEL 8.7 

Configure dependancies 
------------------------------
For Quick install::

    cd ~/qubinode-installer
    ./qubinode-installer -m setup
    ./qubinode-installer -m rhsm
    ./qubinode-installer -m ansible
    ./qubinode-installer -m host
    ./qubinode-installer -p kvm_install_vm


Create  Vyos builder Images -This will be used to build the Vyos image
-----------------------
The following script will crete the debian builder vm internal network::

    $ sudo ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
    $ ./qubinode-installer -p vyos_router -m create

The following script will crete the debian builder vm on a external network::

    $ sudo ssh-keygen -f  /root/.ssh/id_rsa  -t rsa -N ''
    $ cat playbooks/vars/kvm_host.yml | grep use_vyos_bridge #set use vyos bridge to true the default is false 
    use_vyos_bridge: true

    ./qubinode-installer -p vyos_router -m create

In new tab ssh into the builder VM
----------------------------------
In order to start the build process you will need to ssh into the builder vm and run the following commands::

    sudo su - root
    ssh -i /root/.ssh/id_rsa  debian@192.168.122.157
    sudo su - root

Configure a router image vyos env file
-----------------------
Onece on the builder vm you will need to download the vyos-env file and update the variables then run the script::
    
    # wget https://raw.githubusercontent.com/tosin2013/qubinode-installer/master/lib/vyos/vyos-env
    ## edit vyos-env and update the variables
    # vim vyos-env
    # wget https://raw.githubusercontent.com/tosin2013/qubinode-installer/master/samples/scripts/configure-vyos-builder.sh
    # chmod +x configure-vyos-builder.sh
    # ./configure-vyos-builder.sh create

.. By default the script will create a vyos image called vyos-r1.qcow2. You can change the name of the image to deploy a vmware ova by upating the env variable to export TAREGT_ENV=vmware.

Deploy vyos-router on Qubinode
-----------------------
Once the builder vm has created the vyos image you can deploy the image on Qubinode::

    # cd ~/qubinode-installer
    # ./qubinode-installer -p  deploy_vyos_router -m create  vyos-r1.qcow2

For vShpere deployments
-----------------------
Download the ova and deploy it to vcenter the ssh into the router vm and run the following commands::

    # ssh vyos@192.168.1.24 #example ip address you can get the ip by logging into vcenter and looking at the router vm the user name and password is vyos/vyos
    # curl -OL http://192.168.1.66/vsphere-vyos-r2.sh 
    # chmod +x vsphere-vyos-r2.sh
    # bash vsphere-vyos-r2.sh # you will have to reload the ssh session if you are using a different ip address. 

You will have to modify the network adapters before you boot up the ova see the example settings below.

.. image:: https://i.imgur.com/JByipho.png

To Destory builder vm
-----------------------
In order to destroy the router vm you will need to run the following command::

    ./qubinode-installer -p vyos_router -m  destroy  vyos-r1.qcow2

Default Network info for Vyos router
-----------------------
* vyos-network-1 will use dhcp with nat for the vms.
* vyos-network-2 uses static ip  without nat for the vms. 

To Configure the router to use BGP see the below links:
-----------------------
* `Configure two routers using BGP <https://github.com/tosin2013/qubinode-installer/blob/master/lib/vyos/configure_uplinks.md>`_
* `Configure three or more routers using BGP <https://github.com/tosin2013/qubinode-installer/blob/master/lib/vyos/three_routers_config.md>`_
