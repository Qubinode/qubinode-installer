# Qubinode Openshift Cluster Operations 

## Cluster

**Tear down the cluster**

This will remove the cluster, this includes all RHCOS vms and removing dns entries.

```=shell
./qubinode-installer -p ocp4 -d
```

**Report the status of the cluster**

```=shell
./qubinode-installer -p ocp4 -m status
```

**Shutdown the cluster**

```=shell
./qubinode-installer -p ocp4 -m shutdown
```

**Startup the cluster**

```=shell
./qubinode-installer -p ocp4 -m startup
```

## Storage
**To configure nfs-provisioner for registry**
```shell
./qubinode-installer -p ocp4 -a storage=nfs
```

**To remove nfs-provisioner for registry**
```shell
./qubinode-installer -p ocp4 -a storage=nfs-remove
```

**To configure localstorage**
```shell
./qubinode-installer -p ocp4 -a storage=localstorage
```

**To remove localstorage**
```shell
./qubinode-installer -p ocp4 -a storage=localstorage-remove
```

## Workers

Add additional workers to your cluster, the example below will add one
additional worker to your cluster. If your current worker count was 3, this would 
make it 4.

The value for **count** can be 1-10, 10 is the max workers you can add.

NOTE > This automation currently only supports expanding a cluster that as deployed for less
than 24 hrs. If 24rs has lasp follow the steps publish [1]. 

[1] https://access.redhat.com/solutions/4799921

Next copy the ignition file to the webserver container

```
sudo cp /home/admin/qubinode-installer/ocp4/worker.ign /opt/qubinode_webserver/4.4/ignitions/worker.ign
sudo systemctl restart qbn-httpd.service
```

**Add new workers**
```shell
./qubinode-installer -p ocp4 -m add-worker -a count=1
```

**Remove workers**
```shell
./qubinode-installer -p ocp4 -m remove-worker -a count=1
```
