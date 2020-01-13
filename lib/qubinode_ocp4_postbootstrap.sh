#!/bin/bash

#compute-0.ocp42.lunchnet.example Ready worker 42m v1.14.6+8e46c0036
oc get nodes --no-headers=true | while read line
do
    name=$(echo $line | awk '{print $1}')
    state=$(echo $line | awk '{print $2}')
    role=$(echo $line | awk '{print $3}')
    uptime=$(echo $line | awk '{print $4}')
    version=$(echo $line | awk '{print $5}')

    echo "$role $name $state"
done

#csr-5kl7r   50m   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Approved,Issued

CSR_STATE='Approved,Issued'
oc get csr --no-headers=true| while read line
do
    state=$(echo $line | awk '{print $4}')
    if [ "${CSR_STATE}" != "${state}" ]
    then
       printf "%s\n" " Found a CSR that's pending, please investigate and run this check again."
       printf "%s\n" " $line"
    fi
done

#NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
#authentication                             4.2.13    True        False         False      55m

EXPECTED_OPERATORS=27
EXPECTED_DOWN='image-registry'
oc get clusteroperators --no-headers=true| while read line
do
    name=$(echo $line | awk '{print $1}')
    version=$(echo $line | awk '{print $2}')
    status=$(echo $line | awk '{print $3}')
    in_progress=$(echo $line | awk '{print $4}')
    state=$(echo $line | awk '{print $5}')
    uptime=$(echo $line | awk '{print $6}')

    if [[ "A${status}" == 'AFalse' ]] && [[ "A${name}" != "A${EXPECTED_DOWN}" ]]
    then
       printf "%s\n" " The $EXPECTED_DOWN is the only operator expected to be down."
       printf "%s\n" " $name is $status and current state is $state"
       exit 1
    fi
done


# At this point add the nfs-provisioner
# 1. check if it's already added, in case this script is being re-run
# 2. add the nfs-provisioner
# 3. validate is has been added


