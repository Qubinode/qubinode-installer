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
ceph-mon02.$(hostname -d) labels="['mon', 'mgr']"
ceph-mon03.$(hostname -d)  labels="['mon', 'mgr']"
ceph-osd01.$(hostname -d)  labels="['osd']"
ceph-osd02.$(hostname -d)  labels="['osd']"
ceph-osd03.$(hostname -d)  labels="['osd']"

[admin]
ceph-mon01.$(hostname -d)  monitor_address=$(hostname -I) labels="['_admin', 'mon', 'mgr']"
EOF

ansible-playbook -i hosts cephadm-preflight.yml 

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
        docker: false
        registry_url: registry.redhat.io
        registry_username: RHEL_USERNAME
        registry_password: RHEL_PASSWORD

    - name: bootstrap initial cluster
      cephadm_bootstrap:
        mon_ip: "{{ monitor_address }}"
        dashboard_user: admin
        dashboard_password: yourgoingtohavetochangeme
        allow_fqdn_hostname: true
        cluster_network: 10.10.128.0/28

EOF




#ansible-playbook -i hosts bootstrap.yml -vvv --extra-vars "ceph_origin=rhcs"

ansible-galaxy collection install containers.podman

cat >bootstrap-nodes.yml<<EOF
---
- name: bootstrap the nodes
  hosts: all,!ceph-mon01
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
cephadm bootstrap --mon-ip $(hostname -I) --allow-fqdn-hostname
cephadm shell ceph -s
ceph -s

#ceph orch host add ceph-mon02.example.com 192.168.56.65
#ceph orch host add ceph-mon03.example.com 192.168.56.65

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

#ansible-playbook -i hosts cephadm-distribute-ssh-key.yml -e cephadm_ssh_user=root -e admin_node=ceph-mon01

#ansible-playbook -i hosts add-hosts.yml

cat >deploy_osd_service.yml<<EOF
---
- name: deploy osd service
  hosts: ceph-mon01
  become: true
  gather_facts: true
  tasks:
    - name: apply osd spec
      ceph_orch_apply:
        spec: |
          service_type: osd
          service_id: osd
          placement:
            host_pattern: '*'
            label: osd
          spec:
            data_devices:
              all: true
EOF

#ansible-playbook -i hosts deploy_osd_service.yml

#ceph -s
#ceph health
#ceph osd tree

echo "Ceph to consume any available and unused storage device:"
# https://docs.ceph.com/en/latest/cephadm/services/osd/
# ceph osd pool delete {pool-name} [{pool-name} --yes-i-really-really-mean-it
#ceph orch daemon add osd ceph-osd01:/dev/vdb
#ceph orch daemon add osd ceph-osd02:/dev/vdb
#ceph orch daemon add osd ceph-osd03:/dev/vdb
