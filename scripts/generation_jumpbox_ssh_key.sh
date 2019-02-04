#!/bin/bash
set -xe
if [[ -z $1 ]] || [[ -z $2 ]]; then
  echo "please pass IP address for jumpbox"
  echo "EXAMPLE: ./generation_jumpbox_ssh_key.sh username 10.90.21.15"
  exit 1
fi
lastip=`echo "$2" | sed 's/^.*\.\([^.]*\)$/\1/'`
echo $lastip

ssh $1@$2 "ssh-keygen"
ssh $1@$2 "cat ~/.ssh/id_rsa.pub" > /home/$USER/keys/jumpbox.${lastip}.pub
