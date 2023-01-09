Sushy tools deployment
================
Sushy-tools is a set of simulation tools that support the development and testing of Redfish protocol implementations and the Sushy library specifically. It is not intended for use in production environments and should only be run in development and testing environments. [1]

* `Github Page <https://github.com/kenmoini/homelab/tree/main/legacy/containers-as-a-service/caas-sushy>`_


Review the Getting started Guide
------------------------------
`Getting started Guide <https://qubinode-installer.readthedocs.io/en/latest/quick_start.html>`_


Sushy tools Commands:
------------------------------
Deploy sushy tools instance::
    
    ./qubinode-installer -p sushy_tools -m create

Deploy VMs for redfish deployments::

    ./qubinode-installer -p sushy_tools -m create_vms

Destroy VMs for redfish deployments::
    
    ./qubinode-installer -p sushy_tools -m destroy_vms

Destory VMs and sushy tools instance::
    
    ./qubinode-installer -p sushy_tools -m destroy_sushy_tools

Issues 
-------
`homelab <https://github.com/kenmoini/homelab/issues>`_
`Submit Qubinode issues <https://github.com/Qubinode/qubinode-installer/issues>`_

Link
-------
`Redfish development tools <https://github.com/openstack/sushy-tools>`_ 

