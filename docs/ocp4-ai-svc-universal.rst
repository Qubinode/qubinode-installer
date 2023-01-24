OpenShift Assisted Installer Service, Universal Deployer
=========================================================================
A set of resources handles an idempotent way to deploy OpenShift via the Assisted Installer Service to any number of infrastructure platforms.

* `Github Page <https://github.com/kenmoini/ocp4-ai-svc-universal>`_

Review the Getting started Guide
------------------------------
`Getting started Guide <https://qubinode-installer.readthedocs.io/en/latest/quick_start.html>`_

Run the base commands below:: 

    cd ~/qubinode-installer
    ./qubinode-installer -p kcli

Optional deploy gozones DNS::

    ./qubinode-installer -p gozones 

Create Pull Secret::
        
       vim  $HOME/ocp-pull-secret

`Please download the offline token from <https://cloud.redhat.com/openshift/install/pull-secret>`_


Create Pull Secret::
        
       vim  $HOME/rh-api-offline-token

`Please download the offline token from <https://access.redhat.com/management/api>`_

Deploy OpenShift Cluster::

   ./qubinode-installer -p ai_svc_universal -m create

Collect username and password for the OpenShift Console

If you are using bare-net to deploy  OpenShift deploy the jumpbox below.::
    
        sudo ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
        sudo kcli create vm -p ztpfwjumpbox jumpbox --wait
        sudo kcli ssh jumpbox
        kcli info vm jumpbox
    

Destroy OpenShift Cluster::

    ./qubinode-installer -p ai_svc_universal -m destroy

It is recommened to destroy gozone and create a new instance before deploying a cluster after a destroy.

    ./qubinode-installer -p gozones -m removegozones
    ./qubinode-installer -p gozones
    
Issues 
-------
`Submit isues <https://github.com/kenmoini/ocp4-ai-svc-universal/issues>`_