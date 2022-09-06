ZTP for Factory Workflow qubinode dev box
==========================================
`ZTP for Factory Workflow <https://rh-ecosystem-edge.github.io/ztp-pipeline-relocatable/1.0/ZTP-for-factories.html>`_ provides a way for installing on top of OpenShift Container Platform the required pieces that will enable it to be used as a disconnected Hub Cluster and able to deploy Spoke Clusters that will be configured as the last step of the installation as disconnected too.

You can use the qubinode as a dev box gto test out the `ZTP for Factory Workflow <https://rh-ecosystem-edge.github.io/ztp-pipeline-relocatable/1.0/ZTP-for-factories.html>`_.


Recommened install
------------------
* `GitOps Deployment <https://qubinode-installer.readthedocs.io/en/latest/gitops_deployment.html>`_



Create root sshkey::

    sudo su - root
    ssh-keygen


Create pull secret

`Install OpenShift on Bare Metal <https://console.redhat.com/openshift/install/metal/installer-provisioned>`_
 
Pull Secret File::

    vi /root/openshift_pull.json


Clone ztp-pipeline-relocatable repo::

    cd $HOME
    git clone https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable.git
    cd /root/ztp-pipeline-relocatable/hack/deploy-hub-local

Create hub install file:: 

    cat >hub-install.yml<<EOF
    version: stable
    network_type: OVNKubernetes
    kvm_openstack: true
    cluster: ocp4
    domain: labs.qubinode.io
    numcpus: 16
    disk_size: 100
    network: bare-net
    metal3: true
    api_ip: 192.168.150.253
    ingress_ip: 192.168.150.252
    extra_disks:
    - size: 300
    - size: 300
    - size: 300
    EOF

Create NFS file::

    $ vim  nfs.yml
    ---
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: ${PV}
    spec:
      capacity:
        storage: 200Gi
    accessModes:
    - ${MODE}
    nfs:
      path: /var/lib/libvirt/images/${PV}
      server: ${PRIMARY_IP}
    persistentVolumeReclaimPolicy: Recycle


SNO HUB Deployment::

    vim build-hub.sh
    sed -i  's/test-ci/ocp4/' build-hub.sh

    # Change the following variables
    Cluster name  OC_CLUSTER_NAME="ocp4"

    OC_VERSION=$(oc version | awk '{print $3}')
    ./build-hub.sh ${HOME}/openshift_pull.json ${OC_VERSION} 2.5 4.11 sno 



Converged Hub Deployment:: 

    vim build-hub.sh
    sed -i  's/test-ci/ocp4/' build-hub.sh

    OC_VERSION=$(oc version | awk '{print $3}')
    ./build-hub.sh ${HOME}/openshift_pull.json ${OC_VERSION} 2.5 4.11 installer