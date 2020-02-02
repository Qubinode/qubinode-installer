#!/bin/bash

MASTER_ONE=192.168.50.10
MASTER_STATE=$(ping -c3 ${MASTER_ONE} 1>/dev/null; echo $?)

if [ $MASTER_STATE -ne 0 ]
then
    printf "\n It appears the cluster is already down.\n\n"
    exit 0
else
   printf "\ Shutting down the ocp4 cluster.\n"
fi

export KUBECONFIG=/home/admin/qubinode-installer/ocp4/auth/kubeconfig

REGISTER_STATUS=$(oc get clusteroperators | awk '/image-registry/ {print $3}')
CLUSTER_UPTIME=$(oc get clusteroperators | awk '/authentication/ {print $6}')
CLUSTER_UUID=$(oc get clusterversions.config.openshift.io version -o jsonpath='{.spec.clusterID}{"\n"}')
INFRA_ID=$(oc get infrastructures.config.openshift.io cluster -o jsonpath='{.status.infrastructureName}{"\n"}')
HOURS_RUNNING=$(oc get clusteroperators | awk '/authentication/ {print $6}'|tr -d 'h'|tr -d 'd')
BKUP_CMD="sudo /usr/local/bin/etcd-snapshot-backup.sh ./assets/backup/snapshot.db"
NODE_USER="core"
SSH_USER=$(whoami)
USER_SSH_ID="/home/${SSH_USER}/.ssh/id_rsa"
SSH_OPTIONS="-q -o StrictHostKeyChecking=no -o BatchMode=yes"

function shutdown_nodes () {
    for node in $(echo $NODES)
    do
        VM_NAME=$(echo $node|cut -d\. -f1)
        VM_STATE=$(sudo virsh dominfo --domain $VM_NAME | awk '/State/ {print $2}')
        if [ $VM_STATE == "running" ]
        then

            if [ "A${ROLE}" == "Acompute" ]
            then
                # mark node unschedulable
                oc adm cordon $node
                if [ "A$?" != "A0" ]
                then
                    printf "\n Marking $node unschedulable returned $?.\n"
                    printf "\n Please investigate and try again.\n"
                    exit 1
                fi

                # drain node
                oc adm drain $node --ignore-daemonsets --delete-local-data --force --timeout=120s
                if [ "A$?" != "A0" ]
                then
                    printf "\n Draining $node returned $?.\n"
                    printf "\n Continining with shtudwon. Please investigate and try again.\n"
                    # This should prompt the user and ask if they would like t continue with
                    # shutdown or exist and troubleshoot.
                    #exit 1
                fi
            fi 

            printf "\n\n Shutting down $node.\n"
            ssh $SSH_OPTIONS -i $USER_SSH_ID "${NODE_USER}@${node}" sudo shutdown -h now --no-wall

            until [ $VM_STATE != "running" ]
            do
                printf "\n Waiting on $VM_NAME to shutdown. \n"
                VM_STATE=$(sudo virsh dominfo --domain $VM_NAME | awk '/State/ {print $2}')
                sleep 5s
            done
            printf "\n $VM_NAME state is $VM_STATE\n\n"
        else 
            printf "\n $VM_NAME state is $VM_STATE\n\n"
        fi
    done
}


if [ $HOURS_RUNNING -gt 24 ]
then

    printf "\n The ocp4 cluster has been up for more than 24hrs now.\n The current uptime is ${HOURS_RUNNING}\n\n"
    ALL_COMPUTES=$(oc get nodes -l node-role.kubernetes.io/worker="" --no-headers | awk '{print $1}'|sort -r)
    ALL_MASTERS=$(oc get nodes -l node-role.kubernetes.io/master="" --no-headers | awk '{print $1}'|sort -r)

    printf "\n Backing up etcd snapshot.\n\n"
    ssh $SSH_OPTIONS -i $USER_SSH_ID "${NODE_USER}@${MASTER_ONE}" $BKUP_CMD tar tar czf - /home/core/assets/ > /home/${SSH_USER}/ocp4-etcd-snapshot-$(date +%Y%m%d-%H%M%S).tar.gz

    # Mark computes as unscheduleable, drain and shutdown
    ROLE=compute
    NODES=$ALL_COMPUTES
    shutdown_nodes 

    ROLE=master
    NODES=$ALL_MASTERS
    shutdown_nodes 
else
    printf "\n The ocp4 cluster has been up for less that 24hrs now.\n Please wait until after 24rs beforetrying to shutdown the cluster.\n\n"
fi

exit 0
