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


### Add / Remove workers to UPI cluster

[1] https://access.redhat.com/solutions/4799921

Add additional workers to your cluster, the example below will add one
additional worker to your cluster. If your current worker count was 3, this would 
make it 4.

The value for **count** can be 1-10. The count is from 0-9, a count value of 10 will result is nodes 0 - 9.


**Add new workers**
```shell
./qubinode-installer -p ocp4 -m add-worker -a count=1
```

**Remove workers**
```shell
./qubinode-installer -p ocp4 -m remove-worker -a count=1
```
