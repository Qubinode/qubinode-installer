# Walk through the ocp deployment

This example will deploy the core nodes with the ignitions files modified to deploy a custom /etc/hosts

Install the OCP client tools

```
qubinode-installer -p ocp4 -m tools
```

Deploy the node ignitions files
```
qubinode-installer -p ocp4 -m ignitions
```

Modify the ignition files with the customer /etc/hosts
```

# download and deploy filetranspile
mkdir /tmp/filetranspile
cd /tmp/filetranspile
git clone https://github.com/ashcrow/filetranspiler.git
sudo cp filetranspile/filetranspile /usr/local/bin
sudo chmod +x /usr/local/bin/filetranspile

cat << EOF > /tmp/etc-hosts-sinkhole
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.10.10.11 quay.io cloud.openshift.com registry.connect.redhat.com registry.redhat.io
EOF


# add /etc/hosts to ignition files
ignitions="bootstrap worker master"
sudo chown -R admin.admin "${install_dir}"
for name in $(echo "$ignitions")
do
    mkdir "${install_dir}/${name}/etc" -p
    cp /tmp/etc-hosts-sinkhole "${install_dir}/${name}/etc/hosts"
    mv "${install_dir}/${name}.ign" "${install_dir}/${name}.ign.back"
    filetranspile  -i "${install_dir}/${name}.ign.back" -f "${install_dir}/${name}" -o "${install_dir}/${name}.ign"
    rm -rvf "${install_dir}/${name}"
    rm -rvf "${install_dir}/${name}.ign.back"
done

```

Deploy RHCOS nodes

```
qubinode-installer -p ocp4 -m rhcos
```


*You can do this is two steps*
```
qubinode-installer -p ocp4 -m tools
qubinode-installer -p ocp4 -m mirror-rhcos
```

### Others commands available

```
# Bootstrap the cluster after deploying the rhcos nodes
qubinode-installer -p ocp4 -m bootstrap

# Delete the coreos nodes
qubinode-installer -p ocp4 -m rm-rhcos

# Delete and redeploy the cluster
qubinode-installer -p ocp4 -m rebuild
```

