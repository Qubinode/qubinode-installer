# Qubinode Openshift Cluster Operations 

The cluster is deployed with a DNS server by default to provide DNS resolution. You will have
to point to the DNS server running on the Qubinode in order to access your cluster.

## Get the IP address of the dns server

```
./qubinode-installer -p idm -m status
```

Should return some similar to this:

```
     IdM server is installed
   ****************************************************
    Webconsole: https://qbn-dns01.lab.example/ipa/ui/
    IP Address: 192.168.11.13
    Username: admin
    Password: the vault variable admin_user_password

    Run: ansible-vault view $HOME/qubinode-installer/playbooks/vars/vault.yml
```

### Option 1: Update /etc/resolv.conf

**Manually**

Edit /etc/resolv.conf and add the ip address of the IdM server.

```
sudo vi /etc/resolv.conf
```

The result should be:

```
search lab.example
nameserver 192.168.11.13
```

**Using a script**

```
curl -OL https://raw.githubusercontent.com/Qubinode/qubinode-installer/master/lib/qubinode_dns_configurator.sh
chmod +x qubinode_dns_configurator.sh
./qubinode_dns_configurator.sh idm_server_ip openshift_url
```

### Option 2: Have your home router or NetworkManager forward DNS queries

If your home router is built on openwrt or uses dnsmasq for DNS, you can have it forward all dns entries for your OKD domain to the IdM server.

You can also do the same thing with [NetworkManager](https://fedoramagazine.org/using-the-networkmanagers-dnsmasq-plugin/).

## Cluster

The examples below assume you have ocp4 deployed. If you have deployed okd4, just replace ocp4 with okd4.

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
./qubinode-installer -p ocp4 -m storage -a storage=localstorage
```

**To remove localstorage**
```shell
./qubinode-installer -p ocp4 -m storage -a storage=localstorage-remove
```

## Workers


### Add / Remove computes to UPI cluster

[1] https://access.redhat.com/solutions/4799921

Add additional computes to your cluster, the example below will add one
additional compute to your cluster. If your current compute count was 3, this would 
make it 4.

The value for **count** can be 1-10. The count is from 0-9, a count value of 10 will result is nodes 0 - 9.


**Add new computes**
```shell
./qubinode-installer -p ocp4 -m add-compute -a count=1
```

**Remove computes**
```shell
./qubinode-installer -p ocp4 -m remove-compute -a count=1
```

**Configure 20 users on OpenShift using .htaccess**
```
sudo pip3 install passlib
ansible-playbook  -vv playbooks/ocp_htpasswd_users.yml
```
