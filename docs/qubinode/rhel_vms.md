# Deploying Red Hat Enterprise Linux VMs

The qubinode-installer supports deploying Red Hat Enterprise Linux VMs.
This gives you a quick way to spin up one or multiple VMs on KVM running RHEL.

## Prerequisites

Refer to the [Getting Started Guide](README.md) to ensure your system is setup.
There is also a dependancy on IdM as a dns server, refer to the [IdM install](idm.md).

### Deploying a RHEL VM

The RHEL release deployed will default to the release your system in running. You can deploy RHEL 8 or 7 by passing the varible **release=<7 or >** to the installer **-a** argument.
The **-a** agrument can be passed multiple times for set different vairables.

**Install Options**

* name - pet name to give the VM
* size - the size VM to deploy
* release - the release of RHEL to deploy
* qty - the number of VMs to deploy

The VM name is randomly generated when the **name** option is not specified.
The naming convention is qbn-rhel<release>-<random-four-digits>.

* Example: qbn-rhel8-1076

**VM sizes available**

<table>
  <tr>
   <td>
   </td>
   <td>Small
   </td>
   <td>Medium
   </td>
   <td>Large
   </td>
  </tr>
  <tr>
   <td>vCPU
   </td>
   <td>1
   </td>
   <td>2
   </td>
   <td>4
   </td>
  </tr>
  <tr>
   <td>Memory
   </td>
   <td>800Mib
   </td>
   <td>2Gib
   </td>
   <td>8Gib
   </td>
  </tr>
  <tr>
   <td>Disk
   </td>
   <td>10Gib
   </td>
   <td>60Gib
   </td>
   <td>120Gib
   </td>
  </tr>
</table>

**Deploying a RHEL 7 VM**

```=shell
./qubinode-installer -p rhel
```

**Deploying a RHEL 8 VM**

```=shell
./qubinode-installer -p rhel -a release=8
```

**Deploying a large VM**

```=shell
./qubinode-installer -p rhel -a release=8 -a size=large
```

**Deploying 4 medium size RHEL 7 VMs**

```=shell
./qubinode-installer -p rhel -a release=7 -a size=medium -a qty=4
```

**Deploying 6 small size RHEL 8 VMs named webserver**

```=shell
./qubinode-installer -p rhel -a release=8 -a qty=4 -a name=webserver
```

**Deleting a VM**
Deleting a VM requires the name of the VM with the **-d** argument.

```=shell
./qubinode-installer -p rhel -a name=qbn-rhel8-1076 -d
```

**Stopping/Starting a VM**
```=shell

# Stop
./qubinode-installer -p rhel -a name=qbn-rhel8-1076 -m stop

# Start
./qubinode-installer -p rhel -a name=qbn-rhel8-1076 -m start
```

**Get VM status**
```=shell
./qubinode-installer -p rhel -a name=qbn-rhel8-1076 -m status

```

**List all RHEL VMs**
```=shell
./qubinode-installer -p rhel -m list

```
