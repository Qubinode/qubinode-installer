# ZTP for Factory Workflow qubinode dev box 
[ZTP for Factory Workflow](https://rh-ecosystem-edge.github.io/ztp-pipeline-relocatable/1.0/ZTP-for-factories.html) provides a way for installing on top of OpenShift Container Platform the required pieces that will enable it to be used as a disconnected Hub Cluster and able to deploy Spoke Clusters that will be configured as the last step of the installation as disconnected too.

You can use the qubinode as a dev box gto test out the [ZTP for Factory Workflow](https://rh-ecosystem-edge.github.io/ztp-pipeline-relocatable/1.0/ZTP-for-factories.html)


**Optional: configure box**
```
sudo su - admin
curl -OL https://gist.githubusercontent.com/tosin2013/ae925297c1a257a1b9ac8157bcc81f31/raw/71a798d427a016bbddcc374f40e9a4e6fd2d3f25/configure-rhel8.x.sh
chmod +x configure-rhel8.x.sh
./configure-rhel8.x.sh
sudo dnf install libvirt -y
```

**Download Qubinode Installer**
```
cd $HOME
git clone https://github.com/tosin2013/qubinode-installer.git
cd ~/qubinode-installer
git checkout rhel-8.5
```

**copy rhel-8.5-update-2-x86_64-kvm.qcow2 to qubinode-installer directory**

**install latest openshift packages**
```
curl -OL https://raw.githubusercontent.com/tosin2013/openshift-4-deployment-notes/master/pre-steps/configure-openshift-packages.sh
chmod +x configure-openshift-packages.sh
export VERSION=latest-4.9
./configure-openshift-packages.sh -i
```

**Configure Qubinode box**
```
./qubinode-installer -m setup
./qubinode-installer -m rhsm
./qubinode-installer -m ansible
./qubinode-installer -m host
./qubinode-installer -p kcli
```

**Create root sshkey**
```
sudo su - root
ssh-keygen
```
**create pull secret**
```
vi /root/openshift_pull.json
```

**Start ZTP insntaller and spoke cluster** 
> oc version will give you the current version target 
```
sudo su - root
ssh-keygen
exit
OC_VERSION=$(oc version | awk '{print $3}')
sudo lib/build-hub-on-qubinode.sh ${HOME}/openshift_pull.json ${OC_VERSION} 2.4 4.9 installer
# lib/build-spoke.sh ${HOME}/openshift_pull.json ${OC_VERSION} 2.4.3 4.9 installer
```

**deploy jumpbox to access enviornment**
```
sudo kcli create vm -p ztpfwjumpbox jumpbox --wait
```

**Collect Ip address of jumpbox**
> use RDP or Remmina to access Desktop
```
 sudo kcli info vm jumpbox
```

**export cluster name**
```
$ export CLUSTER_NAME="ocp4"
```

**Login to openshift cluster**
```
username: kubeadmin
cat /root/.kcli/clusters/${CLUSTER_NAME}/auth/kubeadmin-password
chmod go-r  /root/.kcli/clusters/ocp4/auth/kubeconfig

```


# Development notes
**to delete cluster**
```
export CLUSTER_NAME="ocp4"
sudo kcli delete cluster ${CLUSTER_NAME}
cd /var/lib/libvirt/images/
sudo rm -rf *.img
sudo rm -rf *.ign
sudo rm -rf pv*
```