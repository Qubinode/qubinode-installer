#!/bin/bash
# Run Script locally on laptop to connect to OpenShift Cluster
# This script is also used to auto configure to the dns server server your qubinode is currently using.
# Tested on Fedora 30

set -xe

read -p 'Enter IDM Server Endpoint: ' idmserver
read -p 'Enter OpenShift Endpoint: ' openshifturl

function check_openshift() {
  OCP_STATUS=$(curl --write-out %{http_code} --silent --output /dev/null "${1}" --insecure)
  echo $OCP_STATUS
}

function testidmserver() {
  ping -q -c5 $1 > /dev/null

  if [ $? -eq 0 ]
  then
    true
  else
    false
  fi
}

function update_resolv_conf(){
  if grep -q ${1} /etc/resolv.conf; then
    echo "nameserver ${1} found"
    cat /etc/resolv.conf
  else
    sudo sed -i '/search.*/i\nameserver '${1}'' /etc/resolv.conf
  fi
}

function final_check() {
  OCP_STATUS=$(check_openshift ${1})
  if [[ $OCP_STATUS -ne 200 ]]
  then
    echo "Updable to access OpenShift. Please Check installation of cluster"
    exit 1
  else
    echo "OpenShift is online. Please open your browser and access it via url."
    printf "\nCluster login: ${1}\n"
    exit 0
  fi
}

if testidmserver ${idmserver}; then
  echo "IDM Server has been found"
  echo "Checking to see if Openshift is online."
  OCP_STATUS=$(check_openshift ${openshifturl})
  if [[ $OCP_STATUS -ne 200 ]]
  then
    echo "Updable to access OpenShift. Please Check installation of cluster"
    echo "Updating resolv.conf"
    update_resolv_conf ${idmserver}
    final_check ${openshifturl}
  else
    echo "OpenShift is online. Please open your browser and access it via url."
    printf "\nCluster login: ${openshifturl}\n"
  fi
else
  echo "IDM Server has not been found will not configure your machine."
fi
