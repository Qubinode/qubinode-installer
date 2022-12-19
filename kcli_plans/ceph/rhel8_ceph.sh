#!/bin/bash 

ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''

cd /usr/share/cephadm-ansible


for i in {1..3}
do
    echo ceph-mon0${i}
    ssh-copy-id root@ceph-mon0${i}
    echo ceph-osd0${i}
    ssh-copy-id root@ceph-osd0${i}
done


cat >hosts<<EOF
ceph-mon02 labels="['mon', 'mgr']"
ceph-mon03 labels="['mon', 'mgr']"
ceph-osd01 labels="['osd']"
ceph-osd02 labels="['osd']"
ceph-osd03 labels="['osd']"

[admin]
ceph-mon01 monitor_address=$(hostname -I) labels="['_admin', 'mon', 'mgr']"
EOF

ansible-playbook -i hosts cephadm-preflight.yml --extra-vars "ceph_origin=rhcs"

cat >bootstrap.yml<<EOF
---
- name: bootstrap the cluster
  hosts: ceph-mon01
  become: true
  gather_facts: false
  tasks:
    - name: login to registry
      cephadm_registry_login:
        state: login
        registry_url: registry.redhat.io
        registry_username: RHEL_USERNAME
        registry_password: RHEL_PASSWORD

    - name: bootstrap initial cluster
      cephadm_bootstrap:
        mon_ip: "{{ monitor_address }}"
        dashboard_user: mydashboarduser
        dashboard_password: mydashboardpassword
        allow_fqdn_hostname: true
        cluster_network: 10.10.128.0/28

EOF

ansible-playbook -i hosts bootstrap.yml -vvv

cat >add-hosts.yml<<EOF
---
- name: add additional hosts to the cluster
  hosts: all
  become: true
  gather_facts: true
  tasks:
    - name: add hosts to the cluster
      ceph_orch_host:
        name: "{{ ansible_facts['hostname'] }}"
        address: "{{ ansible_facts['default_ipv4']['address'] }}"
        labels: "{{ labels }}"
      delegate_to: ceph-mon01

    - name: list hosts in the cluster
      when: inventory_hostname in groups['admin']
      ansible.builtin.shell:
        cmd: ceph orch host ls
      register: host_list

    - name: print current list of hosts
      when: inventory_hostname in groups['admin']
      debug:
        msg: "{{ host_list.stdout }}"
EOF

ceph cephadm get-ssh-config > ssh_config
ceph config-key get mgr/cephadm/ssh_identity_key > ~/cephadm_private_key
chmod 0600 ~/cephadm_private_key
ceph cephadm get-pub-key > ~/ceph.pub

for i in {1..3}
do
    echo ceph-mon0${i}
    ssh-copy-id -f -i ~/ceph.pub root@ceph-mon0${i}
    echo ceph-osd0${i}
    ssh-copy-id -f -i ~/ceph.pub  root@ceph-osd0${i}
done

ansible-playbook -i hosts add-hosts.yml