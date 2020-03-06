# Satellite 6 Installation

The qubinode-installer can install Satellite 6 and configure it. The installation deploys a Red Hat IdM VM. This is use to provide DNS services. Then it deploys a VM to function as the Satellite server. Finally, it configures Satellite server to that it's ready for use.

To proceed you need to get your Satellite server manifest and save as `${projectdir}/satellite-server-manifest.zip`. The project_dir is the location where you have downloaded the Qubinode project. This should be `/home/<username>/qubinode-installer`.

## Installation

You have two options for launching the installation.

#### (1) One shot installation

From the project folder run.

```
./qubinode-install
```

Choose Options:

 - (2) Display other options
 - (4) Satellite - Red Hat Satellite Server
 - Continue with the installation of Satellite? yes

#### (2) Step through the installation.

From the project folder run.

```
./qubinode-install -m setup       # ensure varaibles and sudoers is setup
./qubinode-install -m rhsm        # ensure system is registered to RHSM
./qubinode-install -m ansible     # ensure ansible roles are downloaded
./qubinode-install -m host        # ensure the system is setup as a KVM host
./qubinode-install -p idm         # ensure the IdM server is deployed
./qubinode-install -p satellite   # deploy the satellite server
```

The completed installation will display a menu similar to this:

```
*******************************************************************************
 *  The Satellite server has been deployed with login details below.      *

      Web Url: https://qbn-sat01.lunchnet.example 
      Username: admin 
      Password: the vault variable *admin_user_password* 

      Run: ansible-vault edit /home/admin/qubinode-installer/playbooks/vars/vault.yml
```