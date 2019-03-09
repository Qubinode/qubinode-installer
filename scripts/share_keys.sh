#!/bin/bash
set -x
if [[ -z $1 ]] && [[ -z $2 ]]; then
  echo "Usage: $0 192.168.1.25 username "
  exit 1
fi

USERNAME=${2}
KEYDIRECTORY=~/keys
KEYPATH=$(ls -p ${KEYDIRECTORY})
for key in $KEYPATH; do
  cat $KEYDIRECTORY/$key
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $KEYDIRECTORY/$key  $USERNAME@$1:/tmp
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $USERNAME@$1  "cat /tmp/$key | tee -a /home/${USERNAME}/.ssh/authorized_keys"
done
