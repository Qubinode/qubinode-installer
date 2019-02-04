#!/bin/bash
set -x
if [[ -z $1 ]]; then
  echo "Please pass IP address"
  exit 1
fi

USERNAME="tosin"
KEYDIRECTORY=~/keys
KEYPATH=$(ls -p ${KEYDIRECTORY})
for key in $KEYPATH; do
  cat $KEYDIRECTORY/$key
  scp $KEYDIRECTORY/$key  $USERNAME@$1:/tmp
  ssh $USERNAME@$1  "cat /tmp/$key | tee -a /home/${USERNAME}/.ssh/authorized_keys"
done
