# How to use the Qubinode dev branch

If you download the installer zip, you can do the following.

```
mv qubinode-installer qubinode-installer.old
git clone https://github.com/Qubinode/qubinode-installer.git
cd qubinode-installer
git checkout dev
cp ../qubinode-installer.bkup/playbooks/vars/* playbooks/vars/

# Download the ansible roles
./qubinode-installer -m ansible

# test shutdown
./qubinode-installer -p ocp4 -m shutdown

# test startup
./qubinode-installer -p ocp4 -m startup
```
