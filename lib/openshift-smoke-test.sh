#!/bin/bash
function sleep_for_a_sec() {
  sleep 5s
}

echo "******************************************"
echo "***   Qubinode OpenShift Smoke Test    ***"
echo "******************************************"
sleep_for_a_sec

project_dir_path=$(sudo find / -type d -name qubinode-installer)
project_dir=$project_dir_path
echo ${project_dir}
project_dir="`( cd \"$project_dir_path\" && pwd )`"



domain=$(awk '/^domain:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
ocp_user=$(awk '/^openshift_user:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
product=$(awk '/^qubinode_product_name:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")

oc login https://${product}-master01.${domain}:8443  -u ${ocp_user}

oc new-project validate

oc new-app nodejs-mongo-persistent

NODEJS_MONGO_STATUS=$( oc get pods | grep "nodejs-mongo-persistent" | grep -v build | awk '{print $3}')
MONGO_STATUS=$(oc get pods | grep "mongodb" | awk '{print $3}')
COUNTER=0
while [[ $COUNTER -lt 10  ]]; do
  echo "STATUS: ${NODEJS_MONGO_STATUS}  ${MONGO_STATUS} "
  if [[ "$NODEJS_MONGO_STATUS" == 'Running'  &&  "$MONGO_STATUS" == "Running" ]]; then
    echo "Pods Deployed Successfully"
    oc get pods
    break
  fi
  echo "Waiting for pod to launch."
  sleep 10s
  NODEJS_MONGO_STATUS=$( oc get pods | grep "nodejs-mongo-persistent" | grep -v build |  awk '{print $3}')
  MONGO_STATUS=$(oc get pods | grep "mongodb" | awk '{print $3}')
  let COUNTER=COUNTER+1
done

sleep_for_a_sec

echo "Testing external route to application"
APP_URL=$(oc get routes | grep nodejs | awk '{print $2}')
curl -vs http://$APP_URL || exit 1

sleep_for_a_sec

oc delete all --selector app=nodejs-mongo-persistent

oc delete project validate

echo "******************************************"
echo "*** SMOKE TESTS COMPLTED SUCCESSFULLY  ***"
echo "******************************************"
