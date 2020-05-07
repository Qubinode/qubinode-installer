# This guide will explain how to create a bootable usb.

## Option 1 Generic RHEL 7 bootable usb

### In Linux terminal
**Login as root**
```
$ sudo su -
```
**Ensure your usb shows up. It is normally /dev/sdb**  
Note: if it is already formated it will have a 1 or 2 next to the name
```
$ ls /dev/sd*
/dev/sda  /dev/sda1  /dev/sda2  /dev/sda3  /dev/sdb  /dev/sdb1  /dev/sdb2
```
**Use the dd command to write the installation ISO image directly to the USB device**
Example below
```
$ dd if=/home/testuser/Downloads/rhel-server-7-x86_64-boot.iso of=/dev/sdb bs=512k
8586+0 records in
8586+0 records out
4501536768 bytes (4.5 GB, 4.2 GiB) copied, 1004 s, 4.5 MB/s
```

### Making USB Media on Windows
Find Procedure 3.2. Making USB Media on Windows [Link](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/sect-making-usb-media)

### Install RHEL from Generic USB
Follow instructions found in link below
* https://developers.redhat.com/products/rhel/hello-world#fndtn-rhel
* When using two drives select the SSD as the primaly and allow the nvme to be secondary.
* set root password and create admin user with sudo privilege
* From the software selection choose: Virtualization Host > Virtualization Platform



### May want to install the following tools before deployment
* bind-utils
* unzip

## Option 2 Qubinode  usb


### Qubinode USB
* This will automatically provision Qubinode Box with all th required scripts and qcow images. This currently works with RHEL 7.7.
* Testing and development is welcome for RHEL 8.
Link: https://github.com/Qubinode/qubinode-usb-imager
