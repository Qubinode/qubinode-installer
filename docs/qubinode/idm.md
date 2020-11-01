How does DNS work in qubinode?
-------------------------------

The qubinode-installer deploys Red Hat Identity Manager (IdM) in a VM.

The attributes for the DNS server VM are defined in samples/all.yml under **IDM DNS Server**. The samples/all.yml is copied to playbooks/vars/all.yml when the installer is executed.
Some of the key attributes are listed below.

These should not be changed without understanding the ramifications:

 - idm_admin_user: The default value is **admin**. This is the user to log into the IDM web console.
 - idm_hostname: The default value is  **qbn-dns01**

These values are either set during the install or can be set by the user:

 - dns_server_public: This should be a public DNS server such as Cloudflare's 1.1.1.1 where IdM will forward queries to resolve names outside of your domain
 - idm_public_ip: The IP address of the IdM server. This is auto-populated once the IdM VM has been deployed.
 - idm_admin_password: This is setup when qubinode-installer is executed and it's saved to playbook/vars/vault.yml as **idm_admin_pwd**.

The IdM server can be deployed by executing.

```
./qubinode-installer -p idm
```

This in turn executes the function **qubinode_vm_manager** which then excutes the following:

 * ansible-playbook "${project_dir}/playbooks/deploy-dns-server.yml"
   - Deploys the DNS server VM
   - Adds an entry to inventory/hosts
   - Adds an entry to /etc/hosts
   - Populates *idm_public_ip*
 - ansible-playbook "${project_dir}/playbooks/idm_server.yml"
   - Deploys IDM
   - Set the KVM host /etc/resolv.conf to point to the IDM server

You can remove the IdM server with.
Qubinode Command 
```
./qubinode-installer -p idm -d
```

Ansible command
```
ansible-playbook playbooks/deploy-dns-server.yml --extra-vars "vm_teardown=true"
```

This deletes the IdM server from the inventory/hosts file, /etc/resolv.conf on the KVM host and /etc/host on the KVM host.

Access the IdM Server
---------------------

* ssh

Your ssh-key was copied to IdM vm if you didn't have one it was generated for you.

```
ssh qbn-dns01
```

The web console

 * First step is to make sure your desktop points to the IdM server as a DNS server or by setting up /etc/hosts.
 * Navigate to https://qbn-dns01.lunchnet.example
 * Login as admin the value for **idm_admin_pwd**

You can view this password by runing this command.

```
ansible-vault edit playbooks/vars/vault.yml
```
