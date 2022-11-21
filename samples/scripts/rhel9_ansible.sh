#!/bin/bash 
set -e

if [ $# -ne 2 ]; then 
    echo "No arguments provided"
    echo "Usage: $0 <rhel_username> <rhel_password>"
    exit 1
fi

sudo dnf update -y 
sudo dnf install git vim unzip wget bind-utils tar ansible-core python3 python3-pip util-linux-user -y 
sudo dnf install ncurses-devel curl -y
curl 'https://vim-bootstrap.com/generate.vim' --data 'editor=vim&langs=javascript&langs=go&langs=html&langs=ruby&langs=python' > ~/.vimrc

cd /home/cloud-user/
git clone https://github.com/redhat-cop/agnosticd.git
cd /home/cloud-user/agnosticd/ansible
git checkout development

cat >hosts<<EOF
localhost   ansible_connection=local
EOF

cat >run_me.yaml<<EOF
- name: Install Ansible automation controller
  hosts: localhost
  gather_facts: false
  become: true

  tasks:
    - name: Install Ansible automation controller
      include_role:
        name: aap_download                     
EOF


offline_token=$(cat /root/offline_token)
cat >dev.yml<<EOF
---
offline_token: '$(cat /root/offline_token)'
provided_sha_value: 9a90a8db350b2852471aa987f8487ace7bba85d64219221b5a613647a202e6c1
EOF

ansible-playbook -i hosts run_me.yaml --extra-vars @dev.yml

tar -zxvf aap.tar.gz 
cd ansible-automation-platform-setup-bundle-*/

export REGISTRY_USERNAME="$1"
export REGISTRY_PASSWORD="$2"
VM_IP_ADDRESS=$(hostname -I | awk '{print $1}')

cat >inventory<<EOF
[automationcontroller]
${VM_IP_ADDRESS} ansible_connection=local

[database]

[all:vars]
admin_password='$(openssl rand -base64 12)'

pg_host=''
pg_port=''

pg_database='awx'
pg_username='awx'
pg_password='$(openssl rand -base64 12)'

registry_url='registry.redhat.io'
registry_username='${REGISTRY_USERNAME}'
registry_password='${REGISTRY_PASSWORD}'
EOF

sudo ./setup.sh

echo "https://$VM_IP_ADDRESS" | tee -a /home/cloud-user/aap_info.txt
echo "Username: admin" | tee -a /home/cloud-user/aap_info.txt
echo "Password: $(cat inventory | grep admin_password | awk -F"'" '{print $2}')" | tee -a /home/cloud-user/aap_info.txt

cat /home/cloud-user/aap_info.txt