# Mirror Registry
This application will allow user to easily install Quay and its required components using a simple CLI tool. The purpose is to provide a registry to hold a mirror of OpenShift images.


* [Github Page](https://github.com/quay/mirror-registry)

## Kcli deployment on Qubinode

For Quick install 
```
cd ~/qubinode-installer
./qubinode-installer -m setup
./qubinode-installer -m rhsm
./qubinode-installer -m ansible
./qubinode-installer -m host
./qubinode-installer -p kcli
./qubinode-installer -p gozones
```

### Install Mirror Registry
```
sudo kcli create vm -p mirror_vm mirror_vm --wait
sudo kcli ssh mirror_vm
```

### Collect Ip address of mirror_vm
```
sudo kcli info vm mirror_vm
```
### Optional update dns 
```
sudo vim /opt/disconnected-mirror/dns/volumes/go-zones/zones.yml
```

**Example**
```
        - name: mirror-vm
          ttl: 6400
          value: 192.168.1.180
```

**Restart container**
```
./qubinode-installer -p gozones -m restartcontainer
```

### Remove Jumpbox
```
sudo kcli delete vm mirror_vm
```

## Issues 
[Submit isues](https://github.com/kenmoini/go-zones/issues)


## Links
[Script to configure disconnected environments](https://github.com/tosin2013/openshift-4-deployment-notes/tree/master/disconnected-scripts)
