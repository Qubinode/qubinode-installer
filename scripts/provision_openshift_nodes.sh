#!/bin/bash
set -x
if [[ -z $1 ]]; then
   echo "Please pass inventory.rhel.openshift"
   echo "Usage: $0 inventory.rhel.openshift"
   exit 1
fi

function populate_master_node() {
  if [[ -f master ]]; then
    MASTERIP=$(cat master | tr -d '"[]",')
    echo "${MASTERIP}" >> inventory.vm.provision
  fi
}

function populate_worker_node() {
  NODES=$(ls node*)

  for n in $NODES; do
    NODEIP=$(cat $n | tr -d '"[]",')
    echo "${NODEIP}" >> inventory.vm.provision
  done
}

if [[ -f jumpbox ]]; then
  JUMPBOXIP=$(cat jumpbox | tr -d '"[]",')
cat <<EOF > inventory.vm.provision
[jumpboxdeploy]
${JUMPBOXIP}

EOF
fi

echo "[OSEv3]" >> inventory.vm.provision
populate_master_node
populate_worker_node

if [[ -f lb* ]]; then
  NODES=$(ls lb*)
  for n in $NODES; do
    NODEIP=$(cat $n | tr -d '"[]",')
    echo "${NODEIP}" >> inventory.vm.provision
  done
fi

RESULT=""
MASTERRESULT=""
RESULT=$(grep -A12 '\[nodes:vars\]'  $1 | grep glusterstorage=true   )
MASTERRESULT=$(grep -A12 '\[master:vars\]'  $1  | grep glusterstorage=true )
CHECK_STATE=$(grep glusterstorage=true  inventory.vm.provision)
echo $CHECK_STATE
if [[ -z $CHECK_STATE ]]; then
  echo "" >> inventory.vm.provision
  echo "[gluster]" >> inventory.vm.provision
  if [[ ! -z  "${RESULT}" ]] && [[ ! -z  "${MASTERRESULT}" ]] ; then
    populate_master_node
    populate_worker_node
  elif [[ ! -z  "${RESULT}" ]] ; then
    populate_worker_node
  elif [[ ! -z  "${MASTERRESULT}" ]]; then
    populate_master_node
  fi
  echo "">> inventory.vm.provision
  echo "[gluster:vars]" >> inventory.vm.provision
  echo "glusterstorage=true" >> inventory.vm.provision
fi
