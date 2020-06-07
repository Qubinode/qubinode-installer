# Deploying Red Hat Enterprise Linux VMs

The qubinode-installer supports deploying Red Hat Enterprise Linux VMs.
This gives you a quick way to spin up one or multiple VMs on KVM running RHEL.

## Prerequisites

Refer to the [Getting Started Guide](README.md) to ensure RHEL 7 is installed.

### RHEL QCOW Image

The installer requires the latest rhel 7 and 8 qcow image. You can either manually download or provide your RHSM api token and the installer will download these files for you.

#### Getting the RHEL Qcow Image
<table>
  <tr>
   <td>Using Token
   </td>
   <td>Downloading
   </td>
  </tr>
  <tr>
   <td>Navigate to <a href="https://access.redhat.com/management/api">RHSM API</a> to generate a token and save it as <strong>rhsm_token</strong>. This token will be used to download the rhel qcow image. 
   </td>
   <td>From your web browser, navigate to <a href="https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software">Download Red Hat Enterprise Linux</a>. Download the qcow image matching this checksum the below checksum.
   </td>
  </tr>
</table>

If you are using tokens it should be:
```
* $HOME/qubinode-installer/rhsm_token
```

If you downloaded the files instead it should be:
```
* $HOME/qubinode-installer/rhel-server-7.8-x86_64-kvm.qcow2
* $HOME/qubinode-installer/rhel-8.2-x86_64-kvm.qcow2
```

### Deploying a RHEL VM

The default RHEL release is RHEL 7. You can deploy RHEL 8 by passing the varible release=8 to the installer -a argument.
THe -a agrument can be passed multiple times for set different vairables.

**Install Options**

* name - pet name to give the VM
* size - the size VM to deploy
* release - the release of RHEL to deploy
* qty - the number of VMs to deploy


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

