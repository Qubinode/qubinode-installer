#  Installing OKD - The Community Distribution of Kubernetes 4.x Cluster on a Single Node [Still in Development/Test]

The following documentation will help you deploy an  Community Distribution of Kubernetes  (OKD) 4.x cluster, on a single node.
The installation steps deploys a production like OCP4 cluster, in a environment with 3 masters and 3 workers on a KVM hosts running Red Hat Enterprise Linux (RHEL)
![](https://i.imgur.com/n8TQAyB.png)

## Prerequisites

Refer to the [Getting Started Guide](../README.md) to ensure RHEL 7 or RHEL 8 is installed.

## Install OKD

### Download the qubinode-installer

Download and extract the qubinode-installer as a non root user.

```shell=
cd $HOME
wget https://github.com/Qubinode/qubinode-installer/archive/dev.zip
unzip dev.zip
rm dev.zip
mv qubinode-installer-dev qubinode-installer
```

Place your pull secret and the rhel qcow image under the qubinode-installer directory.

**If you are using tokens it should be:**
```
* $HOME/qubinode-installer/rhsm_token
```

**If you downloaded the files instead it should be:**
```
* $HOME/qubinode-installer/rhel-server-7.8-x86_64-kvm.qcow2
```

**Your Pull secert must contain the following for OKD installs.** 
```
$ cat H$OME/qubinode-installer/pull-secret.txt
  {"auths":{"fake":{"auth": "bar"}}}
```

**cd into qubinode-installer** 
```
$ cd $HOME/qubinode-installer 
```

**install KVM packages and configure bridge and nat networks**
```
$ ./qubinode-installer -p kvm
```

**install idm**  
```
$ ./qubinode-installer -p idm
```

**Copy OKD4 vars file to vars directory**
```
$ cp samples/okd4_baremetal.yml  playbooks/vars/okd4_baremetal.yml
```

**install OKD 4**  
```
$ ansible-playbook playbooks/deploy_okd4.yml
```

**Remove OKD 4**  
```
$ ansible-playbook playbooks/deploy_okd4.yml --extra-vars  "tear_down=true"
```

## Install Options  

### Additional Documentation

* [Qubinode OpenShift Cluster Operations](ocp4_cluster_ops.md)
