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
wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
unzip master.zip
rm master.zip
mv qubinode-installer-master qubinode-installer
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

**install idm**  
```
$ ./qubinode-installer -p idm
```

**Copy OKD4 vars file to vars directory**
```
$ cp samples/okd4_baremetal.yml  playbooks/vars/okd4_baremetal.yml
```

### Optional Steps before installing OKD 4
```
$ vim playbooks/vars/okd4_baremetal.yml
```

**Set the latest okd version**  
https://github.com/openshift/okd/releases

```
ocp4_release: 4.4.0-0.okd-2020-05-23-055148-beta5
```

**Set newest Fedora Cores image tag**

https://getfedora.org/en/coreos/download?tab=metal_virtualized&stream=stable
![FedoraCoresImage](../img/fedora_coreos_images.png)


**Change the following variables in the**
```
major_version: "32.20200601.3.0"  #e.g. 32.20200601.3.0
```

### Begin OKD install
**install OKD 4**  
```
$ ansible-playbook playbooks/deploy_okd4.yml
```

**Remove OKD 4**  
```
$ ansible-playbook playbooks/deploy_okd4.yml --extra-vars  "tear_down=true"
```
**Post Steps**
```
$ oc get nodes
NAME        STATUS   ROLES    AGE   VERSION
compute-0   Ready    worker   11m   v1.17.1
compute-1   Ready    worker   14m   v1.17.1
compute-2   Ready    worker   15m   v1.17.1
master-0    Ready    master   29m   v1.17.1
master-1    Ready    master   28m   v1.17.1
master-2    Ready    master   29m   v1.17.1
```

```
$ oc get co
NAME                                       VERSION                               AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      8m29s
cloud-credential                           4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      32m
cluster-autoscaler                         4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      18m
console                                    4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      6m53s
csi-snapshot-controller                    4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      13m
dns                                        4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      24m
etcd                                       4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      22m
image-registry                             4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      18m
ingress                                    4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      14m
insights                                   4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      18m
kube-apiserver                             4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      22m
kube-controller-manager                    4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      22m
kube-scheduler                             4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      22m
kube-storage-version-migrator              4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      14m
machine-api                                4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      24m
machine-config                             4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      22m
marketplace                                4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      18m
monitoring                                 4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      7m59s
network                                    4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      24m
node-tuning                                4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      25m
openshift-apiserver                        4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      18m
openshift-controller-manager               4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      18m
openshift-samples                          4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      15m
operator-lifecycle-manager                 4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      24m
operator-lifecycle-manager-catalog         4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      24m
operator-lifecycle-manager-packageserver   4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      19m
service-ca                                 4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      25m
service-catalog-apiserver                  4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      25m
service-catalog-controller-manager         4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      25m
storage                                    4.4.0-0.okd-2020-05-23-055148-beta5   True        False         False      18m

```

## Get login info 
```
$ openshift-install --dir "okd4/"  wait-for install-complete
INFO Waiting up to 30m0s for the cluster at https://api.qbn.cloud.qubinode-lab.com:6443 to initialize... 
INFO Waiting up to 10m0s for the openshift-console route to be created... 
INFO Install complete!                            
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/admin/qubinode-installer/okd4/auth/kubeconfig' 
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.qbn.cloud.example-lab.com 
INFO Login to the console with user: kubeadmin, password: mZqM9-xxyzQ-Gr3xP-wj45z 
```

## Shutdown and destory bootstrap node
```
$ sudo virsh destroy bootstrap; sudo virsh undefine bootstrap --remove-all-storage
```

Accessing the cluster web console.

* Option 1: Add dns server to /etc/resolv.conf on your computer.
  - Or run script found under lib/qubinode_dns_configurator.sh
* Option 2: Add dns server to router so all machines can access the OpenShift Cluster.

## Install Options  

### Additional Documentation
#### OKD is still in development some of the qubinode cluster commands may or may not work.
* [Qubinode OpenShift Cluster Operations](ocp4_cluster_ops.md)

### Troubleshooting Tips
[Troubleshooting installation](troubleshooting-monitoring.md)

### Known Issues
```

TASK [ocp4-kvm-deployer : fail if bootstrap process was attempted] ********************************************************************************************
Friday 19 June 2020  16:53:30 -0400 (0:00:00.100)       0:50:02.769 *********** 
fatal: [localhost]: FAILED! => changed=false 
  msg: It appears an installation of the cluster has been attempted. Run /usr/local/bin/qubinode-ocp4-status for more details.
```