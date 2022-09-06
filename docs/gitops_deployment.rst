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
    
    curl -OL https://raw.githubusercontent.com/tosin2013/openshift-virtualization-gitops/main/scripts/install.sh
    chmod +x install.sh
    export CONFIGURE_GITEA=false
    ./install.sh
    sudo su - admin 
    git clone https://github.com/tosin2013/qubinode-installer.git
    exit


Configure GitOps for Qubinode Installer
---------------------------------------
Configure GitOps::
    
    sudo su - root
    systemctl enable podman.socket --now
    mkdir -p /opt/fetchit
    mkdir -p ~/.fetchit
    GITURL="http://yourrepo:3000/tosin/openshift-virtualization-gitops.git"
    # Change Git URL to your Git Repo
    cat  >/root/.fetchit/config.yaml<<EOF
    targetConfigs:
    - url: ${GITURL}
      username: svc-gitea
      password: password
      filetransfer:
      - name: copy-vars
        targetPath: inventories/virtual-lab/host_vars
        destinationDirectory: /home/admin/qubinode-installer/playbooks/vars
        schedule: "*/1 * * * *"
      branch: main
    EOF

    cp /home/admin/openshift-virtualization-gitops/scripts/fetchit/fetchit-root.service /etc/systemd/system/fetchit.service
    systemctl enable fetchit --now

    podman ps 

    exit

Deploy Qubinode Installer
-------------------------
Confirm Qubinode vars have been copied to vars directory::

        sudo su - admin 
        ls -l /home/admin/qubinode-installer/playbooks/vars


Decrypt ansible vault file password if it exisits in git repo::

    sudo su - admin 
    export vault_key_file="/home/admin/.vaultkey"
    export vaultfile="/home/admin/qubinode-installer/playbooks/vars/vault.yml"
    echo "YourPassword" > "${vault_key_file}"
    ansible-vault decrypt "${vaultfile}"

Deploy Qubinode Installer with godns::
    
    sudo su - admin
    cd /home/admin/qubinode-installer
    ./qubinode-installer -m setup
    ./qubinode-installer -m rhsm
    ./qubinode-installer -m ansible
    ./qubinode-installer -m host
    ./qubinode-installer -p kcli
    ./qubinode-installer -p gozones
