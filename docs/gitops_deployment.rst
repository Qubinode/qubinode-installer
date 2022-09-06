=====================
GitOps Deployment
=====================

Configure Repo
--------------
To use locally follow the link below 
`OpenShift Virtualization GitOps Repository <https://openshift-virtualization-gitops-repository.readthedocs.io/en/latest/#openshift-virtualization-gitops-repository>`_

To use external Git repo use the following steps::
    
    curl -OL https://raw.githubusercontent.com/tosin2013/openshift-virtualization-gitops/main/scripts/install.sh
    chmod +x install.sh
    export CONFIGURE_GITEA=false
    ./install.sh
    sudo su - admin 
    git clone http://gitea.example.com:3000/tosin/openshift-virtualization-gitops.git
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