#!/bin/bash
# A menu driven shell script sample template
## ----------------------------------
# Step #1: Define variables
# ----------------------------------
EDITOR=vim
PASSWD=/etc/passwd

# Define colours
RED='\033[0;41;30m'
STD='\033[0;0;39m'
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'


ocp3_vars_file="${playbooks_dir}/vars/ocp3.yml"

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
source "${project_dir}/lib/qubinode_openshift3_utils.sh"

qubinode_required_prereqs
auto_install=$(awk '/^openshift_auto_install:/ {print $2}' "${ocp3_vars_file}")


if [[ -z $1 ]]; then
  printf "%s\n" "${mag}No Flag has been passed.${end}"
  exit 1
fi

INSTALLTYPE=$1
arr=('minimal', 'standard', 'performnance')
match=$(echo "${arr[@]:0}" | grep -o $1)

if [[ ! -z $match ]]
then
    printf "%s\n\n" " Setting OpenShift cluster profile to $INSTALLTYPE"
else
    printf "%s\n" "The flag $INSTALLTYPE passed is not valid. "
    printf "%s\n" "Valid flags are  minimal, standard, performnance."
    exit 1
fi


# ----------------------------------
# Step #2: User defined function
# ----------------------------------

function user_choose_profile () {
    printf "%s\n\n" " ${cyn} Please choose an OpenShift Cluster Profile"
    show_menus
    read_options
}

# function to display menus
show_menus() {
    printf "%s\n" "  ${cyn}~~~~~~~~~~~~~~~~~~~~~~~~~~~~${end}"
    printf "%s\n" "  ${yel}Qubinode OpenShift Profiles${end}"
    printf "%s\n" "  ${cyn}~~~~~~~~~~~~~~~~~~~~~~~~~~~~${end}"
    printf "%s\n" "    1. Minimal Deployment"
    printf "%s\n" "    2. Standard Deployment"
    printf "%s\n" "    3. Performance Deployment"
    printf "%s\n" "    4. Exit"
}

function continue_with_selected_install () {
            printf "%s\n" ""
            sed -i "s/openshift_deployment_size:.*/openshift_deployment_size: $ocp_size/g" "${ocp3_vars_file}"
            openshift_size_vars_file="${project_dir}/playbooks/vars/openshift3_size_${ocp_size}.yml"
            cp -f ${project_dir}/samples/ocp_vm_sizing/${ocp_size}.yml ${openshift_size_vars_file}
            exit 0
}

function read_options(){
	local choice
	read -p " ${cyn}Enter choice [ 1 - 5] ${end}" choice
	case $choice in
		1) ocp_size=minimal
                   ;;
                2) ocp_size=standard
                   ;;
                3) ocp_size=performance
                   ;;
		4) exit 0;;
		*) printf "%s\n\n" " ${RED}Error...${STD}" && sleep 2
	esac
        confirm " Continue with $ocp_size openshift 3 cluste deployment? yes/no"
        if [ "A${response}" == "Ayes" ]
        then
            continue_with_selected_install
        else
            user_choose_profile
        fi
}

# ----------------------------------------------
# Step #3: Trap CTRL+C, CTRL+Z and quit singles
# ----------------------------------------------
trap '' SIGINT SIGQUIT SIGTSTP

# -----------------------------------
# Step #4: Main logic - infinite loop
# ------------------------------------

if [[ ! -z ${INSTALLTYPE} ]]
then
    printf "%s\n\n" " ${cyn}Your OpenShift Cluster deployment profile is ${INSTALLTYPE}${end}"
    printf "%s\n" "    This will deploy the following. "
    case "${INSTALLTYPE}" in
        minimal)
                 openshift3_minimal_desc
                 ;;
        standard)
                 openshift3_standard_desc
                 ;;
        performance)
                 openshift3_performance_desc
                 ;;
        *) exit 0;;
    esac

    printf "%s\n" ""
    confirm " ${cyn}Would you like a customize this deployment? yes/no${end}"
    echo    # (optional) move to a new line
    if [ "A${response}" == "Ayes" ]
    then
        user_choose_profile
    elif [ "A${response}" == "Ano" ]
    then
        case $INSTALLTYPE in
        minimal)
            ocp_size=minimal
            continue_with_selected_install
            ;;
        standard)
            ocp_size=standard
            continue_with_selected_install
            ;;
        performance)
            ocp_size=performance
            continue_with_selected_install
            ;;
            *) exit 0;;
        esac
    else
        while true
        do
            user_choose_profile
        done
    fi
fi

exit 0
