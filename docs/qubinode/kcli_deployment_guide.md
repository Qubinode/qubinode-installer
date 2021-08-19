# Kcli on Qubinode - (Experimental)
This tool is meant to interact with existing virtualization providers (libvirt, KubeVirt, oVirt, OpenStack, VMware vSphere, GCP and AWS) and to easily deploy and customize VMs from cloud images.

You can also interact with those VMs (list, info, ssh, start, stop, delete, console, serialconsole, add/delete disk, add/delete nic, ...).

* [Kcli documentation](https://kcli.readthedocs.io/en/latest/)
* [Github Page](https://github.com/karmab/kcli)

## Kcli deployment on Qubinode

For Quick install 
```
cd ~/qubinode-installer
./qubinode-installer -m setup
./qubinode-installer -m rhsm
./qubinode-installer -m ansible
./qubinode-installer -m host
./qubinode-installer -p kcli
```

### Qubinode Maintance commands

Update default settings for qubinode deployments
```
./qubinode-installer -p kcli -m updatedefaults
```

Download default profile images 
```
./qubinode-installer -p kcli -m configureimages
```

### Create use the kcli

Create vm with rhel8 profile
```
sudo kcli create vm -p rhel8 testvm
```

Get vm info
```
sudo kcli  info vm testvm
```


Delete vm
```
sudo kcli  delete vm testvm
```


## Typical commands
* List vms
  * `kcli list vm`
* List cloud images
  * `kcli list images`
* Create vm from a profile named base7
  * `kcli create vm -p base7 myvm`
* Create vm from profile base7 on a specific client/host named twix
  * `kcli -C twix create vm -p base7 myvm`
* Delete vm
  * `kcli delete vm vm1`
* Do the same without having to confirm
  * `kcli delete vm vm1 --yes`
* Get detailed info on a specific vm
  * `kcli info vm vm1`
* Start vm
  * `kcli start vm vm1`
* Stop vm
  * `kcli stop vm vm1`
* Switch active client/host to bumblefoot
  * `kcli switch host bumblefoot`
* Get remote-viewer console
  * `kcli console vm vm1`
* Get serial console (over TCP). Requires the vms to have been created with kcli and netcat client installed on hypervisor
  * `kcli console vm -s vm1`
* Deploy multiple vms using plan x defined in x.yml file
  * `kcli create plan -f x.yml x`
* Delete all vm from plan x
  * `kcli delete plan x`
* Add 5GB disk to vm1, using pool named images
  * `kcli create vm-disk -s 5 -p images vm1`
* Delete disk named vm1_2.img from vm1
  * `kcli delete disk --vm vm1 vm1_2.img`
* Update memory in vm1 to 2GB memory
  * `kcli update vm -m 2048 vm1`
* Clone vm1 to new vm2
  * `kcli clone vm -b vm1 vm2`
* Connect with ssh to vm vm1
  * `kcli ssh vm vm1`
* Create a new network
  * `kcli create network -c 192.168.7.0/24 mynet`
* Create new pool
  * `kcli create pool -t dir -p /hom/images images`
* Add a new nic from network qubinet to vm1
  * `kcli create nic -n qubinet vm1`
* Delete nic eth2 from vm
  * `kcli delete nic -i eth2 vm1`
* Create snapshot named snap1 for vm1:
  * `kcli create snapshot vm -n vm1 snap1`
* Get info on your kvm setup
  * `kcli info host`
* Export vm:
  * `kcli export vm vm1`

## Issues 
[Submit isues](https://github.com/karmab/kcli/issues)