GoZones DNS
================
GoZones is an application that will take DNS Zones as defined in YAML and generate BIND-compatable DNS Zone files and the configuration required to load the zone file.

GoZones can operate in single-file input/output batches, or via an HTTP server.

* `Github Page <https://github.com/kenmoini/go-zones>`_


Review the Getting started Guide
------------------------------
`Getting started Guide <https://qubinode-installer.readthedocs.io/en/latest/quick_start.html>`_

Kcli deployment on Qubinode
------------------------------

Run the base commands below:: 


    cd ~/qubinode-installer
    ./qubinode-installer -p kcli
    ./qubinode-installer -p gozones


Qubinode Maintance commands
------------------------------
Remove Gozones DNS::
    
    ./qubinode-installer -p gozones -m removegozones



To update DNS
------------------------------
1. Modify the script below and restart the gozones container 
2. script coming soon to modify gozones::

    sudo vim /opt/service-containers/config/server.yml
    ./qubinode-installer -p gozones -m restartcontainer

3. You can also update inventories/your-server/host_vars/dns-server.yml in git then::

    # Check playbooks/vars/dns-server.yml
    ./qubinode-installer -p gozones -m restartcontainer

Issues 
-------
`Submit isues <https://github.com/kenmoini/go-zones/issues>`_


