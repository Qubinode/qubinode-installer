# OpenShift 4.x Cluster Advanced Deployment 

Please refer to [Installing an OpenShift 4.x Cluster on a Single Node](openshift4_installation_steps.md) b
efore continuing here.

****setup playbooks vars and user sudoers****  
```
./qubinode-installer -m setup
```

****register host system to Red Hat****  
```
./qubinode-installer -m rhsm
```
****update to RHEL 7.7 if you are using 7.6****
```
sudo yum update -y
```

****setup host system as an ansible controller****
```
./qubinode-installer -m ansible
```

****setup host system as an ansible controller****
```
./qubinode-installer -m host
```

****install idm dns server****
```
./qubinode-installer -p idm
```

****Optional: Uninstall idm dns server****

This may be used when there is an issue with the deployment. Note that idm is required for OpenShift 4.x installations.
```
./qubinode-installer  -p idm -d
```

****Install OpenShift 4.x****
```
./qubinode-installer -p ocp4
```

**Additional options**  

*To configure shutdown before 24 hours*
```
$ cd /home/$USER/qubinode-installer
$ ansible-playbook playbooks/deploy_ocp4.yml  -t enable_shutdown
```

*To configure nfs-provisioner for registry*
```
./qubinode-installer -p ocp4 -a storage=nfs
```

*To remove nfs-provisioner for registry*
```
./qubinode-installer -p ocp4 -a storage=nfs-remove
```

*To configure localstroage*
```
$ cd /home/$USER/qubinode-installer
$ ansible-playbook playbooks/deploy_ocp4.yml  -t localstorage
```

## Deployment Post Steps

How to access OpenShift Cluster
* Option 1: Add dns server to /etc/resolv.conf on your computer.
  - Or run script found under lib/qubinode_dns_configurator.sh
* Option 2: Add dns server to router so all machines can access the OpenShift Cluster.
