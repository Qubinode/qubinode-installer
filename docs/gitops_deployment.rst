=====================
GitOps Deployment
=====================


.. note::
    * Changes to deployments are made in the target Git repository. Then synced down to machine using fetchit. The commands will reference the synced repo configs down to the machine.


Configure Repo
--------------
To use locally follow the link below 

* `OpenShift Virtualization GitOps Repository <https://openshift-virtualization-gitops-repository.readthedocs.io/en/latest/#openshift-virtualization-gitops-repository>`_

To use external Git repo use the following steps::
    
    curl -OL https://raw.githubusercontent.com/tosin2013/kvm-gitops/main/scripts/install.sh
    chmod +x install.sh
    export CONFIGURE_GITEA=false
    ./install.sh
    sudo su - admin 
    git clone https://github.com/tosin2013/qubinode-installer.git
    

Optional: Configure GitOps for Qubinode Installer
---------------------------------------
Configure GitOps::

    sudo su - root
    curl -OL https://raw.githubusercontent.com/tosin2013/kvm-gitops/main/scripts/example_script.sh
    chmod +x example_script.sh
    ./example_script.sh qubinode-installer <directory_path>  http://gitea.example.com:3000/myrepo/kvm-gitops.git gituser password

Confirm Qubinode vars have been copied to vars directory::

        sudo su - admin 
        ls -l /home/admin/qubinode-installer/playbooks/vars


Decrypt ansible vault file password if it exisits in git repo::

    sudo su - admin 
    export vault_key_file="/home/admin/.vaultkey"
    export vaultfile="/home/admin/qubinode-installer/playbooks/vars/vault.yml"
    echo "YourPassword" > "${vault_key_file}"
    ansible-vault decrypt "${vaultfile}"

Deploy Qubinode Installer with gozones
-------------------------------------
Start Deployment:: 
    
    sudo su - admin
    cd /home/admin/qubinode-installer
    ./qubinode-installer -m setup
    ./qubinode-installer -m rhsm
    ./qubinode-installer -m ansible
    ./qubinode-installer -m host
    ./qubinode-installer -p kcli
    ./qubinode-installer -p gozones
    sudo ssh-keygen # for root user login when creating VMs


Save Succcessful Deployment Files 
---------------------------------
1. if openshift-virtualization-gitops not in come ``git clone http://yourrepo:3000/tosin/openshift-virtualization-gitops.git``.
2. On Successful deployment cp vars from /home/admin/qubinode-installer/playbooks/vars/ to  openshift-virtualization-gitops/inventories/supermicro/host_vars/
3. Push to openshift-virtualization-gitops repo