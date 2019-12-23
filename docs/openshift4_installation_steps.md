# OpenShift 4.2 Cluster on a Single Node

Follow these steps to deploy OpenShift 4.2 cluster on a single node.
This deploys 3 masters and 3 computes.

**Download files for qubinode installation**
```
wget https://github.com/Qubinode/qubinode-installer/archive/releasev2.2.zip
unzip releasev2.2.zip
mv qubinode-installer-releasev2.2 qubinode-installer
rm -f releasev2.2.zip
cd qubinode-installer/
```
**setup playbooks vars and user sudoers**  
```
./qubinode-installer -m setup
```

**register host system to Red Hat***  
```
./qubinode-installer -m rhsm
```
**Update to RHEL 7.7 if you are using 7.6**
```
sudo yum update -y
```

**setup host system as an ansible controller**
```
./qubinode-installer -m ansible
```

**setup host system as an ansible controller**
```
./qubinode-installer -m host
```
**Download qcow images for idmserver**
```
copy rhel-server-7.7-update-2-x86_64-kvm.qcow2 to qubinode-installer directory
```

**install idm dns server**
```
./qubinode-installer -p idm
```

**Optional: Uninstall idm dns server. This may be used when there is an issue with the deployment. Note that idm is required for OpenShift 4.x installations.**
```
./qubinode-installer  -p idm -d
```

**Prerequisites**
```
Please download your pull-secret from:
https://cloud.redhat.com/openshift/install/metal/user-provisioned
and save it as /home/admin/qubinode-installer/pull-secret.txt
```

**Install OpenShift 4.x**
```
./qubinode-installer -p ocp4
```

**Optional: Uninstall idm dns server**
```
./qubinode-installer  -p ocp4 -d
```
