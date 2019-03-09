#!/bin/bash
set -xe
if [[ -z $1 ]] || [[ -z $2 ]]; then
  echo "please pass IP address for jumpbox"
  echo "EXAMPLE: ./generation_jumpbox_ssh_key.sh username 10.90.21.15"
  exit 1
fi

if [[ ! -f hosts ]]; then
  echo "Hosts file not found."
  echo "pleae run sudo ansible-playbook -i inventory.openshift  tasks/hosts_generator.yml"
  exit 1
fi

USERNAME=$1

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  hosts  $USERNAME@$2:/tmp
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $USERNAME@$2  sudo -u root /bin/bash -c "cat /tmp/hosts >> tee -a /etc/hosts"
