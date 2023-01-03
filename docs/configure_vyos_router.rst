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

    sudo ssh-keygen
    lib/vyos/deploy-vyos-builder.sh create

The following script will crete the debian builder vm on a external network::

    sudo ssh-keygen
    lib/vyos/deploy-vyos-builder.sh create bridge

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


Deploy vyos-router on Qubinode
-----------------------
Once the builder vm has created the vyos image you can deploy the image on Qubinode::

    # cd ~/qubinode-installer
    # lib/vyos/deploy-vyos-router.sh create vyos-r1.qcow2


To Destory builder vm
-----------------------
In order to destroy the router vm you will need to run the following command::

     lib/vyos/deploy-vyos-builder.sh destroy



