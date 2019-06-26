#!/bin/bash
set -xe
if [[ -z $1 ]] || [[ -z $2 ]]; then
  echo "please pass IP address for jumpbox"
  echo "EXAMPLE: ./generation_jumpbox_ssh_key.sh username 10.90.21.15"
  exit 1
fi
lastip=`echo "$2" | sed 's/^.*\.\([^.]*\)$/\1/'`
echo $lastip

echo -e "\e[32m************************\e[0m"
echo -e "\e[32mGenerate SSH-KEY for jumpbox ${2}\e[0m"
echo -e "\e[32m************************\e[0m"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  $1@$2 "ssh-keygen -b 4096 -t rsa -f ~/.ssh/id_rsa -q -N ''" || exit 1
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  $1@$2 "cat ~/.ssh/id_rsa.pub" > /root/keys/jumpbox.${lastip}.pub || exit 1
