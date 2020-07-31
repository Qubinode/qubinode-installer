# LDAP OpenShift configuration 


### install ldapsearch
```
sudo dnf install openldap-clients -y
```

### Create users in IDM 
**run playbook**
```
$ ansible-playbook  -v  playbooks/populate_idm.yml
```

**Test**
```
$ ssh administrator@server.idm.example.com
$ ipa user-show student00
```

## Configure OpenShift 

**run the playbook**
```
ansible-playbook -v playbooks/openshift_ldap.yml
```

## Configure clusteradmin you may optionally change the password
1. Login to idm server via web browser 
2. Click on actions then `Reset Password`
![](https://i.imgur.com/WzBtlHT.png)
3. default clusteradmin password is `clusteradmin`
![](https://i.imgur.com/M1LlmC8.png)
4. Click on `ldapidp`
![](https://i.imgur.com/jM8ZhPQ.png)
5. Login to OpenShift with new Password
![](https://i.imgur.com/46AfUUP.png)
6. Give clusteradmin admin rights from oc cli on qubinode
```
oc adm policy add-cluster-role-to-user cluster-admin clusteradmin
```
7. Remove kubeadmin 
```
oc delete secrets kubeadmin -n kube-system
```


### IDM LDAP TESTING 
[EXAMPLES OF COMMON LDAPSEARCHES](https://access.redhat.com/documentation/en-us/red_hat_directory_server/10/html/administration_guide/examples-of-common-ldapsearches)
```
$ curl https://qbn-dns01.qubinode-lab.com/ipa/config/ca.crt -k -o /home/admin/ipa-ca.crt
```

**Export ipa cert**
```
$ export LDAPTLS_CACERT=$HOME/ipa-ca.crt
```

**Test ldap search**
```
Export Variables
$ DOMAIN1=qubinode-lab
$ DOMAIN2=com
```

**Print all objects in ldap**
```
$ ldapsearch -x -H ldaps://qbn-dns01.qubinode-lab.com  -b "dc=${DOMAIN1},dc=${DOMAIN2}"
```

**Get student info**
```
$ export  STUDENT_NUM=student00
$ ldapsearch -x -H ldaps://qbn-dns01.qubinode-lab.com  -b "uid=${STUDENT_NUM},cn=users,cn=accounts,dc=${DOMAIN1},dc=${DOMAIN2}"
```

**Get Cluster admin info**
```
$ ldapsearch -x -H ldaps://qbn-dns01.qubinode-lab.com  -b "uid=clusteradmin,cn=users,cn=accounts,dc=${DOMAIN1},dc=${DOMAIN2}"
```

## OpenShift Group sync
```
curl -OL https://raw.githubusercontent.com/Qubinode/qubinode-installer/dev/playbooks/templates/ldap-groups-sync.yaml
```

**Edit the following line numbers**
* 55
* 61
* 70


**Create Deployment**
```
oc create -f ldap-groups-sync.yaml
```

**Check openshift-authentication for cron job status**


### Links: 
* https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/pdf/configuring_and_managing_identity_management/Red_Hat_Enterprise_Linux-8-Configuring_and_managing_Identity_Management-en-US.pdf
* https://blog.danman.eu/openshift-4-automatic-ldap-group-synchronization/
* https://github.com/redhat-cop/openshift-management