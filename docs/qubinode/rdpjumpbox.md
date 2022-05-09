# Centos Jumpbox Deployment
This doc will show how to deploy a CentOS jumpbox.

## Centos deployment on Qubinode

For Quick install 
```
cd ~/qubinode-installer
./qubinode-installer -m setup
./qubinode-installer -m rhsm
./qubinode-installer -m ansible
./qubinode-installer -m host
./qubinode-installer -p kcli
./qubinode-installer -p gozones
sudo kcli create vm -p ztpfwjumpbox jumpbox --wait
```

## ScreenShots
![20220509192238](https://i.imgur.com/qc7r6Eu.png)

![20220509192553](https://i.imgur.com/MeHNdGE.png)

### Collect Ip address of jumpbox
> use RDP or Remmina to access Desktop
```
sudo kcli info vm jumpbox
```

```
sudo kcli ssh jumpbox "ip addr"
```
u
### Delete Jumpbox
```
sudo kcli delete vm jumpbox
```