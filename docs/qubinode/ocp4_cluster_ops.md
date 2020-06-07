# Qubinode Openshift Cluster Operations 

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
