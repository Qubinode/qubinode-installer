#!/bin/bash

function config_err_msg () {
    cat << EOH >&2
  There was an error finding the full path to the qubinode-installer project directory.
EOH
}

# this function just make sure the script
# knows the full path to the project directory
# and runs the config_err_msg if it can't determine
# that start_deployment.conf can find the project directory
function setup_required_paths () {
    current_dir="`dirname \"$0\"`"
    project_dir="$(dirname ${current_dir})"
    project_dir="`( cd \"$project_dir\" && pwd )`"
    if [ -z "$project_dir" ] ; then
        config_err_msg; exit 1
    fi

    if [ ! -d "${project_dir}/playbooks/vars" ] ; then
        config_err_msg; exit 1
    fi
}

setup_required_paths
openshift3_variables

function sleep_for_a_sec() {
  sleep 5s
}

echo "******************************************"
echo "***   Qubinode OpenShift Smoke Test    ***"
echo "******************************************"
sleep_for_a_sec


oc login ${web_console}:8443  -u ${ocp_user}
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

exit 0
