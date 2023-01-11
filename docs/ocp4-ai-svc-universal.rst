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

`lease download the offline token from <https://cloud.redhat.com/openshift/install/pull-secret>`_


Create Pull Secret::
        
       vim  $HOME/rh-api-offline-token

`Please download the offline token from <https://access.redhat.com/management/api>`_

Deploy OpenShift Cluster::

   ./qubinode-installer -p ai_svc_universal -m create

Destroy OpenShift Cluster::

    ./qubinode-installer -p ai_svc_universal -m destroy