#!/bin/bash

web_console="$1"
ocp_user="$2"
ocp_user_password="$3"

oc login ${web_console} --username=${ocp_user} --password=$ocp_user_password --insecure-skip-tls-verify=true
if [ $? -eq 1 ]
then
    echo "Log to $web_console failed as user $ocp_user"
    exit 1
else
    echo "Log into to $web_console as user $ocp_user"
fi

oc new-project validate > /dev/null 2>&1
oc new-app nodejs-mongo-persistent > /dev/null 2>&1

NODEJS_MONGO_STATUS=$( oc get pods | grep "nodejs-mongo-persistent" | grep -v build | awk '{print $3}')
MONGO_STATUS=$(oc get pods | grep "mongodb" | awk '{print $3}')
COUNTER=0
while [[ $COUNTER -lt 10  ]]; do
  echo "STATUS: ${NODEJS_MONGO_STATUS}  ${MONGO_STATUS} "
  if [[ "$NODEJS_MONGO_STATUS" == 'Running'  &&  "$MONGO_STATUS" == "Running" ]]; then
    echo "Pods Deployed Successfully"
    oc get pods > /dev/null 2>&1
    break
  fi
  echo "Waiting for pod to launch."
  sleep 10s
  NODEJS_MONGO_STATUS=$( oc get pods | grep "nodejs-mongo-persistent" | grep -v build |  awk '{print $3}')
  MONGO_STATUS=$(oc get pods | grep "mongodb" | awk '{print $3}')
  let COUNTER=COUNTER+1
done

echo "Testing external route to application"
APP_URL=$(oc get routes | grep nodejs | awk '{print $2}')
APP_STATUS=$(curl --write-out %{http_code} --silent --output /dev/null "http://$APP_URL")

oc delete all --selector app=nodejs-mongo-persistent > /dev/null 2>&1
oc delete project validate > /dev/null 2>&1

if [ "A${APP_STATUS}" == "A200" ]
then
    echo "******************************************"
    echo "*** SMOKE TESTS COMPLETED SUCCESSFULLY ***"
    echo "******************************************"
    exit 0
else
    echo "******************************************"
    echo "*** SMOKE TESTS FAILED                 ***"
    echo "******************************************"
    exit 1
fi

