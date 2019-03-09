#!/bin/bash
set -xe

if [[ -f jumpbox ]]; then
  JUMPBOXIP=$(cat jumpbox | tr -d '"[]",')
cat <<EOF > inventory.vm.provision
[jumpboxdeploy]
${JUMPBOXIP}

EOF
fi

echo "[OSEv3]" >> inventory.vm.provision
if [[ -f master ]]; then
  MASTERIP=$(cat master | tr -d '"[]",')
  echo "${MASTERIP}" >> inventory.vm.provision
fi


  NODES=$(ls node*)

  for n in $NODES; do
    NODEIP=$(cat $n | tr -d '"[]",')
    echo "${NODEIP}" >> inventory.vm.provision
  done



if [[ -f lb* ]]; then
  NODES=$(ls lb*)
  for n in $NODES; do
    NODEIP=$(cat $n | tr -d '"[]",')
    echo "${NODEIP}" >> inventory.vm.provision
  done
fi
