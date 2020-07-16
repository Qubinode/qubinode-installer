# Red Hat Ansible Automation

## Prerequisites

Refer to the [Getting Started Guide](../README.md) to ensure RHEL 8 is installed.
There is also a dependancy on IdM as a dns server, refer to the [IdM install](idm.md).

#### Get a Red Hat Ansible Automation Platform license 
Link: https://www.redhat.com/en/technologies/management/ansible/try-it

Place the tower license in the file below.
```
* $HOME/qubinode-installer/tower-license.txt
```

### Deploying Ansible tower 

Below are the following flags for a tower deployment 

*Deploy ansible tower* 
```
./qubinode-installer -p tower
```

*To Delete Tower* 
```
./qubinode-installer -p tower -d
```
