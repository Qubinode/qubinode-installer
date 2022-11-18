#!/bin/bash 

sudo dnf install git vim unzip wget bind-utils tar ansible-core python3 python3-pip util-linux-user -y 
sudo dnf install ncurses-devel curl -y
curl 'https://vim-bootstrap.com/generate.vim' --data 'editor=vim&langs=javascript&langs=go&langs=html&langs=ruby&langs=python' > ~/.vimrc

git clone https://github.com/redhat-cop/agnosticd.git
cd $HOME/agnosticd/ansible
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



