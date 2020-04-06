#!/bin/bash

function config_err_msg () {
    cat << EOH >&2
    printf "%s\n\n" " ${red}There was an error finding the full path to the qubinode-installer project directory.${end}"
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
source "${project_dir}/lib/qubinode_installer_prereqs.sh"
source "${project_dir}/lib/qubinode_utils.sh"
source "${project_dir}/lib/qubinode_requirements.sh"


export KUBECONFIG="${project_dir}/ocp4/auth/kubeconfig"

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
AVAILABLE_OPERATORS=()
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

    # Count
done

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

    # Count
done

# A. Deploy nfs-provisioner
# At this point add the nfs-provisioner
# 1. check if it's already added, in case this script is being re-run
# 2. add the nfs-provisioner

# 3. validate is has been added
if ! oc describe configs.imageregistry.operator.openshift.io | grep -q 'Claim:   image-registry-storage'
then
    # oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'
    oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"pvc":{ "claim": " image-registry-storage"}}}}'
fi

# B. Complete OpenShift install
# 1. do a until loop until all the expected operators are up
# 2. run openshift-install --dir=ocp4 wait-for install-complete

# C. print status about the cluster

exit 0

