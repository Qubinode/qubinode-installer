
# Installing The Qubinode
# Introduction


The qubinode is a prescriptive installation of either Red Hat OpenShift Platform or The Origin Community Distribution of Kubernetes.

:numbered:

## Installing Red Hat Enterprise Linux

 - [RHEL Installation Walkthrough](https://developers.redhat.com/products/rhel/hello-world#fndtn-rhel)

* Get your developer subscription of RHEL
* Download the RHEL 7.7 iso
* From the software selection choose: Virtualization Host > Virtualization Platform
* If using two storage devices install choose the correct one for RHEL installation. If using the recommend storage options. Install RHEL on the ssd. The installer will delicate the majority of your storage to /home, you can choose "I will configure partitioning" to have control over this.
* Configure NETWORK & HOSTNAME
* Begin installation
* set root password and create admin user with sudo privilege

## Prepare the system
One RHEL has been installed on your system, ensure the system has internet connection. The qubinode-installer expects that your already have DHCP running in your environment for the purpose of supplying IP addresses for the VM nodes.

[NOTE]
The current working branch for the qubinode-installer is the developer branch.

. Login remotely to the Qubinode box as  as the qubinode admin user

```
ssh <your-user>@<your-system-ip-address>
```

. Download the qubinode-installer project

```
wget https://github.com/Qubinode/qubinode-installer/archive/2.3.1.zip
unzip 2.3.1.zip
mv qubinode-installer-2.3.1 qubinode-installer
rm -f 2.3.1.zip
cd qubinode-installer/
```

. Download the qcow image
 From your web browser:

. Navigate to: https://access.redhat.com/downloads/content/69/ver#/rhel---7/7.8/x86_64/product-software
. Find *Red Hat Enterprise Linux 7.8 KVM Guest Image* and right click on the *Download Now" box
. wget -c "insert-url-here" -O rhel-server-7.8-x86_64-kvm.qcow2 

:numbered:

## Qubinode Installation Quickstart
```
$ ./qubinode-installer
Loading function qubinode_required_prereqs





   ************************************************************************************
   The default product option is to install Red Hat Openshift Container Platform (OCP).
   An subscription for OCP is required. If you do not have an OCP subscription. Please
   display the menu options for other product installation such as OKD.

   The OCP cluster deployment consist of:

     - 1 IDM server for DNS
     - 1 Master node
     - 2 App nodes
     - 2 Infra nodes

   Gluster is deployed as the container storage running on the infra and app nodes.

   If you wish to continue with this install choose the **continue** option otherwise
   display the help menu to see the available options.
   ************************************************************************************




1) Continue with the default installation
2) Display the help menu
#?
```

## Qubinode Advanced OpenShift Installation Steps
**setup        - setup playbooks vars and user sudoers**
```
./qubinode-installer -m setup
```

**rhsm         - register host system to Red Hat**
```
./qubinode-installer -m rhsm
```

**ansible      - setup host system as an ansible controller**
```
./qubinode-installer -m ansible
```

**if your rhel version is older than 7.7 upgrade**
```
sudo yum update -y
```

**host         - setup the host system as an KVM host**
```
./qubinode-installer -m host
```

**idm - deploy idm server that will manage dns for your openshift cluster**
```
./qubinode-installer -p idm
```

**If for any reason you need to remove the idm vm run this command**
```
./qubinode-installer -p idm  -d
```

**deploy_nodes - deploy all VMS to install ocp3/okd3, supports -d**
```
 ./qubinode-installer -m deploy_nodes
```

**To delete and remove ocp3**
```
 ./qubinode-installer -p ocp3 -m deploy_nodes -d
```

**Deploy OpenShift**
```
 ./qubinode-installer -p ocp3
```

## Installing the container platform

The installer supports installing either Red Hat OpenShift (OCP) or The Origin Community Distribution of Kubernetes (OKD).

Executing the qubinode-installer without any arguments will prompt to inform you about the default installation choice and give you the option to continue or to display the help menu.

[NOTE]
The continue with the default installation has not been implemented yet.

The installer accepts arguments to either to change the behavior of the installation. The *-p* argument is always required. The options for *-p* are: *ocp* for OpenShift or *okd* for The Origin Community.. .

### Installing OpenShift in stages

In this example we will walk through each stage of the installer to get OpenShift installed.

. Run setup to satisfy all perquisites*

```
 ./qubinode-installer -p ocp -m setup

```
#### The setup run down

. Setup password-less sudoers

If your user login isn't already setup for sudo, you will be prompted twice for the *root* users password. This is used to setup your user for password-less sudoers.
If your user is already setup for sudo, you will be prompted for the users password to setup password-less sudoers.

. Copy the required files from samples to their respective paths.
  - all.yml > playbooks/vars/all.yml
  - vault.yml > playbooks/vars/vault.yml
  - hosts > inventory/hosts

. Collect networking information, the defaults are acceptable for most users.
  - prompts you for the domain you would like to use
  - prompts you for upstream DNS server, this is a DNS server that can return results not known the local DNS server deployed by the qubinode-installer.
  - prompts you for you IP network, aka subnet
  - your gateway and systems ip address are also collected automatically, this is use to setup your bridge network that will allow incoming traffic to your qubinode

. Takes your current username and use it as the admin user for all VMs to be created. You will be prompted to enter a password for this user. You can use the current password or enter a new one for this purpose.

. The qubinode-installer deploys Red Hat Identity Management as the DNS server.
  - Prompts you to enter a password that has to be 8 or more characters long, the user *admin* will be created with this password. You will be able to log into the IdM console here: https://ocp-dns01.<yourdomain>.

. Collects your RHSM credentials. This is used to register RHEL to the Red Hat Customer Portal and also OpenShift if you have an OpenShift subscription.
  - Prompts you to choose between using a Activation Key or Username and Password. If doing an OpenShift install your RHSM username and password is required and you will be prompted for it if you choose option *(1)*. Unless you understand activation keys, the best option is *(2)*.

#### Register the system to Red Hat
The qubinode-installer leverage Red Hat Enterprise Linux as the foundation. In order to get updates and install additional software all RHEL systems must be registered to the Red Hat Customer Portal (RHSM).

Execute the RHSM stage:
```
  ./qubinode-installer -m rhsm -p ocp

```

- Registers your system to RHSM.
- Gets the pool id if installing OpenShift.

#### Setup Ansible Engine
The qubinode-installer leverages ansible automation as do the OCP/OKD's own installer.

Execute the Ansible stage:
```
  ./qubinode-installer -m ansible -p ocp

```

- Installs all Ansible dependencies.
- Ensure the support ansible repository is enabled.
- Generates an ansible vault file *~/.vaultkey* and encrypts the playbooks/vars/vault.yml file.
- Downloads all the roles specified in playbooks/requirements.yml

#### Setup your system as a KVM host
The qubinode-installer leverages linux virtualization hypervisor KVM and the Libvirt management tools. This stage configures your system to function as a KVM host.

[NOTE]
In our setup we leverage a 1TB NVME for the storage of the VMs. This is highly recommend and the installer by default expects to setup /var/lib/libvirt/images on a dedicated storage device.

Execute the KVM host stage:
```
  ./qubinode-installer -m host -p ocp

```
- Ensure the system is registered to RHSM and installs all required packages
- Creates a

#### Setup idm for dns server
The OpenShift nodes will use this as the external server to the cluster. End users will also point to this dns server to access the OpenShift cluster.
Execute the IDM stage:
```
  ./qubinode-installer -p idm

```

To remove IDM run the following
```
  ./qubinode-installer -p idm -d

```
*For OKD Deployments please remove the machine from the list of registered systems on https://access.redhat.com/management/systems*

#### Deploy the  vms used for the OpenShift Development
This commannd will deploy the VMs that OpenShift will run on. Running the command below will prepare your hosts for OpenShift deployment. Write a-records to the IDM server to be used by OpenShift.

.Summary of actions
- Register hosts with Red Hat Subscription Manager (RHSM)
- Install base packages required for OpenShift
- Install docker
- Configure Docker Storage
- Configure OverlayFS
- Configure thin pool storage
- Configure Red Hat Gluster Storage

Execute the following command to deploy the nodes using  OpenShift Enterprise use the command below:
```
  ./qubinode-installer -p ocp -m deploy_nodes

```

To remove the nodes run the following
```
  ./qubinode-installer -p ocp -d

```
*For OKD Deployments please remove the machine from the list of registered systems on https://access.redhat.com/management/systems*

#### Deploy OpenShift
This command will deploy OpenShift on the vms that where deployed on the previous step.

.Summary of Actions
- Configure the host to deploy OpenShift
- Auto generate the openshift-ansible inventory file.
- Configure the .htpasswd file with qubinode as default user.
- Run a Qubimode OpenShift deployment check to ensure the environment is ready to deploy OpenShift.
- Run the offical  playbooks/prerequisites.yml This playbook installs required software packages, if any, and modifies the container runtimes.
- Run the offical playbooks/deploy_cluster.yml

Execute the following command to deploy OpenShift Enterprise use the command below:
```
  ./qubinode-installer -p ocp

```

To uninstall Openshift across all hosts in the cluster.
```
  ./qubinode-installer -p ocp -m uninstall_openshift

  # OpenShift Origin Command
  ./qubinode-installer -p okd -m uninstall_openshift

```

## Deployment Post Steps
#### How to access OpenShift Cluster
- Option 1: add dns server to /etc/resolv.conf on your computer
  - Or run script found under lib/qubinode_dns_configurator.sh
- Option 2: add dns server to router so all machines can access the OpenShift Cluster

#### Testing the Deployment
- Check Health of cluster
```
./qubinode-installer  -c checkcluster
```
- Run Smoke test on environment
```
./qubinode-installer  -c smoketest
```
- Optional: Run Advanced Health Check
```
./qubinode-installer  -c diag
```

## Day Two Operations
- Start up OpenShift cluster after shutdown
```
./qubinode-installer  -c startup
```
- Safely shutdown OpenShift cluster
```
./qubinode-installer  -c shutdown
```
