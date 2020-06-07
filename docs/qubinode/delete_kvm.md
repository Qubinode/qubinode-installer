# Ansible play to delete vm

## Delete vm
```
sudo ansible-playbook -i inventory.openshift tasks/delete_kvm.yml  --extra-vars "machine=vmname"

```

## Delete Jumpbox
```
sudo ansible-playbook -i inventory.openshift tasks/delete_kvm.yml  --extra-vars "machine=jumpbox"

```

## Delete master
```
sudo ansible-playbook -i inventory.openshift tasks/delete_kvm.yml  --extra-vars "machine=master"

```

## Delete all nodes
```
sudo ansible-playbook -i inventory.openshift tasks/delete_kvm.yml  --extra-vars "machine=nodes"

```

## Delete load balancer   
```
sudo ansible-playbook -i inventory.openshift tasks/delete_kvm.yml  --extra-vars "machine=lb"

```
