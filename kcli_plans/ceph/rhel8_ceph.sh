#!/bin/bash 

ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''

cd /usr/share/cephadm-ansible


for i in {1..3}
do
    echo ceph-mon0${i}.$(hostname -d)
    ssh-copy-id root@ceph-mon0${i}.$(hostname -d)
    echo ceph-osd0${i}.$(hostname -d)
    ssh-copy-id root@ceph-osd0${i}.$(hostname -d)
done


cat >hosts<<EOF
ceph-mon02.$(hostname -d) labels="['mon', 'mgr']"
ceph-mon03.$(hostname -d)  labels="['mon', 'mgr']"
ceph-osd01.$(hostname -d)  labels="['osd']"
ceph-osd02.$(hostname -d)  labels="['osd']"
ceph-osd03.$(hostname -d)  labels="['osd']"

[admin]
ceph-mon01.$(hostname -d)  monitor_address=$(hostname -I) labels="['_admin', 'mon', 'mgr']"
EOF

ansible-playbook -i hosts cephadm-preflight.yml 


ansible-galaxy collection install containers.podman

cat >bootstrap-nodes.yml<<EOF
---
- name: bootstrap the nodes
  hosts: all
  become: true
  gather_facts: false
  tasks:
    - name: login to registry
      cephadm_registry_login:
        state: login
        docker: false
        registry_url: registry.redhat.io
        registry_username: RHEL_USERNAME
        registry_password: RHEL_PASSWORD
    - name: Login to default registry and create ${XDG_RUNTIME_DIR}/containers/auth.json
      containers.podman.podman_login:
        username: RHEL_USERNAME
        password: RHEL_PASSWORD
        registry: registry.redhat.io
EOF


ansible-playbook -i hosts bootstrap-nodes.yml -vvv
cephadm bootstrap --mon-ip $(hostname -I) --allow-fqdn-hostname | tee -a /root/cephadm_bootstrap.log
cephadm shell ceph -s
ceph -s

ceph cephadm get-pub-key > ~/ceph.pub
ssh-copy-id -f -i ~/ceph.pub root@$(dig ceph-mon02.$(hostname -d) +short)
ssh-copy-id -f -i ~/ceph.pub root@$(dig ceph-mon03.$(hostname -d) +short)
ssh-copy-id -f -i ~/ceph.pub root@$(dig ceph-osd01.$(hostname -d) +short)
ssh-copy-id -f -i ~/ceph.pub root@$(dig ceph-osd02.$(hostname -d) +short)
ssh-copy-id -f -i ~/ceph.pub root@$(dig ceph-osd03.$(hostname -d) +short)
ceph orch host add ceph-mon02 $(dig ceph-mon02.$(hostname -d) +short)
ceph orch host add ceph-mon03 $(dig ceph-mon03.$(hostname -d) +short)
ceph orch host label add ceph-mon01 mon
ceph orch host label add ceph-mon02 mon
ceph orch host label add ceph-mon03 mon
ceph orch apply mon ceph-mon01,ceph-mon02,ceph-mon03
ceph orch host ls
ceph orch ps
echo "waiting 120s for mons to be up"
sleep 120s
ceph orch host add ceph-osd01 $(dig ceph-osd01.$(hostname -d) +short)
ceph orch host add ceph-osd02 $(dig ceph-osd02.$(hostname -d) +short)
ceph orch host add ceph-osd03 $(dig ceph-osd03.$(hostname -d) +short)
ceph orch host label add ceph-osd01 osd
ceph orch host label add ceph-osd02 osd
ceph orch host label add ceph-osd03 osd
echo "waiting 120s for osds to be up"
sleep 120s
ceph orch apply osd --all-available-devices
#ceph orch daemon add osd ceph-osd01:/dev/vdb
#ceph orch daemon add osd ceph-osd02:/dev/vdb
#ceph orch daemon add osd ceph-osd03:/dev/vdb
echo "waiting 120s for osds to be up"
sleep 120s 
ceph osd tree
echo "configuring ocs pool"
ceph osd pool create ocs 64 64
#ceph osd pool application enable ocs rbd




