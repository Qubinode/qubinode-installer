#!/bin/bash

web_console="$1"
ocp_user="$2"
ocp_user_password="$3"

oc login ${web_console} --username=${ocp_user} --password=$ocp_user_password --insecure-skip-tls-verify=true
if [ $? -eq 1 ]
then
    echo "Log to $web_console failed as user $ocp_user"
    exit 1
fi
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

