TailScale 
================
Tailscale is a zero config VPN for building secure networks. Install on any device in minutes. Remote access from any network or physical location.

* `Tailscale <https://tailscale.com/>`_
* `Github Page <https://github.com/tailscale>`_

Kcli deployment on Qubinode
------------------------------
For Quick install::

    cd ~/qubinode-installer
    ./qubinode-installer -m setup
    ./qubinode-installer -m rhsm
    ./qubinode-installer -m ansible
    ./qubinode-installer -m host
    ./qubinode-installer -p kcli



Deploy TailScale VM using qubindoe bridge network
--------------------
The following command will deploy a tailscale VM using the qubinode bridge network.::

    sudo kcli create vm -p tailscale tailscale  --wait

Once the VM has been deployed you may login to tailscale website and autehnticate the VM.
Example:: 

    To authenticate, visit:

        https://login.tailscale.com/a/xXxXxXxXxXxX


Connection information for tailscale vm
-------------------------------

If you would like to access the vm use the commands below::
    
    sudo kcli info vm tailscale
    sudo kcli ssh tailscale