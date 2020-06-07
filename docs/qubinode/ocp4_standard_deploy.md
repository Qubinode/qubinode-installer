# OpenShift 4.x Standard Cluster Deployment

Please refer to [Installing an OpenShift 4.x Cluster on a Single Node](openshift4_installation_steps.md) before continuing here.

Run the below command to kick off the deployment of 6 node OCP4 cluster.
This will consist of 3 masters 3 workers and NFS for persistent storage.
Each node will be deployed with 16 Gib memory and 4 vCPUs.

```shell=
cd $HOME/qubinode-installer
./qubinode-installer
```

*Select Option 1: Continue with the default installation*

![](https://i.imgur.com/LS8p6j1.png)

**This will perform the following**
* Configure server for KVM.
* Deploy an idm server to be used as DNS.
* Deploy OpenShift 4.
* Optional: Configure NFS Provisioner

## Deployment Post Steps

Accessing the cluster web console.

* Option 1: Add dns server to /etc/resolv.conf on your computer.
  - Or run script found under lib/qubinode_dns_configurator.sh
* Option 2: Add dns server to router so all machines can access the OpenShift Cluster.

**Optional Install Cockpit**  
**In order to manage and view cluster from a web ui on RHEL 7**  
```
subscription-manager repos --enable=rhel-7-server-extras-rpms
subscription-manager repos --enable=rhel-7-server-optional-rpms
sudo yum install  cockpit cockpit-networkmanager cockpit-dashboard \
  cockpit-storaged cockpit-packagekit cockpit-machines cockpit-sosreport \
  cockpit-pcp cockpit-bridge -y
sudo systemctl start cockpit
sudo systemctl enable cockpit.socket
sudo firewall-cmd --add-service=cockpit
sudo firewall-cmd --add-service=cockpit --permanent
sudo firewall-cmd --reload
```

**go to your servers url for cockpit ui**
```
https://SERVER_IP:9090
```

**Additional cluster operations commands are avialable [here](ocp4_cluster_ops.md)**

