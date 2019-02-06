#!/bin/bash
set -xe
JUMPBOXIP=$(cat jumpbox | tr -d '"[]",')
cat <<EOF > inventory.vm.provision
[jumpboxdeploy]
${JUMPBOXIP}

EOF

echo "[OSEv3]" >> inventory.vm.provision

MASTERIP=$(cat master | tr -d '"[]",')
echo "${MASTERIP}" >> inventory.vm.provision

NODES=$(ls node*)

for n in $NODES; do
  NODEIP=$(cat $n | tr -d '"[]",')
  echo "${NODEIP}" >> inventory.vm.provision
done


NODES=$(ls lb*)

for n in $NODES; do
  NODEIP=$(cat $n | tr -d '"[]",')
  echo "${NODEIP}" >> inventory.vm.provision
done
