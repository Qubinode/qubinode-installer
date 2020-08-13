# Troubleshooting an monitoring for Qubinode

WIP

While OpenShift is deploying you can open a new terminal sshh into your box and run the following. 


When Bootstrap is starting 
```
# OpenShift 
tail -f /home/${USER}/qubinode-installer/ocp4/bootstrap-complete.log

# OKD 
tail -f /home/${USER}/qubinode-installer/okd/bootstrap-complete.log
```

Waiting for Installation to Complete
```
# OpenShift 
tail -f /home/${USER}/qubinode-installer/ocp4/.openshift_install.log

# OKD 
tail -f /home/${USER}/qubinode-installer/okd4/.openshift_install.log
```

**To exit out of tail hit CTRL+C**

To view Logs and status on Red Hat Cores OS bootstrap node
```
$ ssh core@192.168.50.2
```

To view logs and status on Fedora Cores OS bootstrap node
```
$ ssh core@192.168.50.2
$ journalctl -b -f -u release-image.service -u bootkube.service

```

### OpenShift node info on Qubinode

list vms
```
$ sudo virsh list 
 Id    Name                           State
----------------------------------------------------
 11    qbn-dns01                      running
 34    ctrlplane-0                    running
 35    ctrlplane-1                    running
 36    ctrlplane-2                    running
 37    compute-0                      running
 38    compute-1                      running
 39    compute-2                      running

```

###  From the CLI
*virt-top*

```
# virt-top --help
virt-top : a 'top'-like utility for virtualization

SUMMARY
  virt-top [-options]

OPTIONS
  -1                Start by displaying pCPUs (default: tasks)
  -2                Start by displaying network interfaces
  -3                Start by displaying block devices
  -b                Batch mode
  -c uri            Connect to libvirt URI
  --connect uri     Connect to libvirt URI
  --csv file        Log statistics to CSV file
  --no-csv-cpu      Disable CPU stats in CSV
  --no-csv-mem      Disable memory stats in CSV
  --no-csv-block    Disable block device stats in CSV
  --no-csv-net      Disable net stats in CSV
  -d delay          Delay time interval (seconds)
  --debug file      Send debug messages to file
  --end-time time   Exit at given time
  --hist-cpu secs   Historical CPU delay
  --init-file file  Set name of init file
  --no-init-file    Do not read init file
  -n iterations     Number of iterations to run
  -o sort           Set sort order (cpu|mem|time|id|name|netrx|nettx|blockrdrq|blockwrrq)
  -s                Secure ("kiosk") mode
  --script          Run from a script (no user interface)
  --stream          dump output to stdout (no userinterface)
  --block-in-bytes  show block device load in bytes rather than reqs
  --version         Display version number and exit
  -help             Display this list of options
  --help            Display this list of options
```
[virt-top-> more info](https://people.redhat.com/rjones/virt-top/virt-top.txt)

.KVM logs location
* as ${USER}istrator
* cd /var/log/libvirt/qemu
* tail one of the following based of vm name
```
# ls -lath qbn-*
-rw-------. 1 root root  29K Aug 17 10:10 qbn-dns01.log
-rw-------. 1 root root  29K Aug 17 10:08 qbn-lb01.log
-rw-------. 1 root root  49K Aug 17 10:07 qbn-infra02.log
-rw-------. 1 root root  54K Aug 17 10:05 qbn-infra01.log
-rw-------. 1 root root  44K Aug 17 10:04 qbn-node02.log
-rw-------. 1 root root  50K Aug 17 10:03 qbn-node01.log
-rw-------. 1 root root 104K Aug 17 10:01 qbn-controlplan01.log
```

### From Cockpit
