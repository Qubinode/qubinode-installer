# GoZones DNS
GoZones is an application that will take DNS Zones as defined in YAML and generate BIND-compatable DNS Zone files and the configuration required to load the zone file.

GoZones can operate in single-file input/output batches, or via an HTTP server.

* [Github Page](https://github.com/kenmoini/go-zones)

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

### Qubinode Maintance commands

Remove Gozones DNS
```
./qubinode-installer -p gozones -m removegozones
```


### To update DNS
> Modify the script below and restart the gozones container 
> script coming soon to modify gozones
```
sudo vim /opt/disconnected-mirror/dns/volumes/go-zones/zones.yml
./qubinode-installer -p gozones -m restartcontainer
```

## Issues 
[Submit isues](https://github.com/kenmoini/go-zones/issues)
