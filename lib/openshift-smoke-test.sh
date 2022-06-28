#!/bin/bash

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

source "${project_dir}/lib/qubinode_openshift3_utils.sh"

web_console="$1"
ocp_user="$2"
ocp_user_password="$3"
SMOKE_TEST_RETURN_CODE=0

openshift3_smoke_test $web_console $ocp_user $ocp_user_password
openshift3_smoke_test_return 
printf "%s\n" "${SMOKE_MSG}"


exit 0

2 oc login failed
3 creating project failed
4 smoke test app success
5 smoke test app failed
