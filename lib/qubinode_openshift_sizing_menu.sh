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

# Uncomment for debugging
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x


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
source "${project_dir}/lib/qubinode_ocp4_utils.sh"
source "${project_dir}/lib/qubinode_utils.sh"

openshift4_variables

qubinode_required_prereqs
if [[ -f ${ocp3_vars_file} ]]; then 
  auto_install=$(awk '/^openshift_auto_install:/ {print $2}' "${ocp3_vars_file}")
fi 

if [[ -z $1 ]]; then
  printf "%s\n" "${mag}No Flag has been passed.${end}"
  exit 1
fi

INSTALLTYPE=$1
arr=('minimal', 'standard', 'custom', 'notmet')
match=$(echo "${arr[@]:0}" | grep -o $1)

if [[ -z $match ]]
then
    printf "%s\n" "The flag $INSTALLTYPE passed is not valid. "
    printf "%s\n" "Valid flags are  minimal, standard, performnance, custom, notmet."
    exit 1
fi


# ----------------------------------
# Step #2: User defined function
# ----------------------------------

function user_choose_profile () {
    show_menus
    read_options
}

function user_choose_ocp4_profile () {
    show_menus_ocp4
    read_options_ocp4
}

# function to display menus
show_menus () {
    printf "%s\n" "  ${cyn}~~~~~~~~~~~~~~~~~~~~~~~~~~~~${end}"
    printf "%s\n" "  ${yel}Qubinode OpenShift Profiles${end}"
    irintf "%s\n\n" " ${cyn} Please choose an OpenShift Cluster Profile"
    printf "%s\n" "  ${cy6}~~~~~~~~~~~~~~~~~~~~~~~~~~~~${end}"
    printf "%s\n" "    1. Minimal Deployment"
    printf "%s\n" "    2. Standard Deployment"
    printf "%s\n" "    3. Performance Deployment"
    printf "%s\n" "    4. Exit"
}

# function to display menus
show_menus_ocp4 () {
    printf "%s\n" ""
    printf "%s\n" "    ${yel}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${end}"
    printf "%s\n" "    ${cyn}Qubinode OpenShift 4.x Profiles${end}"
    printf "%s\n\n" "    ${yel}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${end}"

    printf "%s\n" "    All cluster deployment options defaults to 3 ctrlplane nodes."
    printf "%s\n" "    A cluster with 3 nodes is smallest cluster deployment size"
    printf "%s\n" "    supported by the OCP4 installer. When deploying 3 nodes only, each node"
    printf "%s\n" "    gets assigned the role of compute and ctrlplane. Each cluster is deployed"
    printf "%s\n\n" "    with NFS for persistent storage."

    printf "%s\n" "    ${cyn}Minimal Cluster Deployment Options${end}"
    printf "%s\n" "    These options require a minimum of 32 Gib memory for the 3 node"
    printf "%s\n" "    option and 64 Gib for the 4 node option. A minimum of 6 cores"
    printf "%s\n" "    is recommended . The 3 node option deploys each node with 10 Gib"
    printf "%s\n" "    memory and 4 vCPUs. The 4 node option deploys each node with 12"
    printf "%s\n\n" "    Gib memory and 4 vCPUs."

    printf "%s\n" "    ${cyn}Standard Cluster Deployment Options${end}"
    printf "%s\n" "    These options require a minimum of 96 Gib memory and 8 cores."
    printf "%s\n" "    This will deploy the default configuration of 3 ctrlplane and 3 computes"
    printf "%s\n" "    or 3 ctrlplane and 2 computes. The 6 node option includes the option to"
    printf "%s\n\n" "    deploy persistent local storage."

    printf "%s\n" "    ${cyn}Custom Cluster Deployment Options${end}"
    printf "%s\n" "    This option will allow you to: "
    printf "%s\n" "        * Increase the number of computes "
    printf "%s\n" "        * Change the memory, storage, and vcpu for each node"
    printf "%s\n" ""
    printf "%s\n" "      1. Minimal 3 node cluster"
    printf "%s\n" "      2. Minimal 4 node cluster"
    printf "%s\n" "      3. Standard 5 node cluster"
    printf "%s\n" "      4. Standard 6 node cluster with local storage"
    printf "%s\n" "      5. Custom Deployment"
    printf "%s\n" "      6. Reset to defaults"
    printf "%s\n" "      7. Continue with install"
    printf "%s\n\n" ""
}

function read_options(){
	local choice
	read -p "   ${cyn}Enter choice [ 1 - 6] ${end}" choice
	case $choice in
	1) ocp_size=minimal
           minimal_opt=ctrlplane_only
           confirm_minimal_deployment
           ;;
        2) ocp_size=minimal
           minimal_opt=ctrlplane_compute
           confirm_minimal_deployment
           ;;
        3) ocp_size=performance
            ;;
	4) exit 0
            ;;
	*) printf "%s\n\n" " ${RED}Error...${STD}" && sleep 2
	esac
        user_choose_profile
}

function read_options_ocp4 () {
	local choice
	read -p "   ${cyn}Enter choice [ 1 - 7] ${end}" choice
	case $choice in
        1) ocp_size=minimal
           minimal_opt=ctrlplane_only
           confirm_minimal_deployment
           ;;
        2) ocp_size=minimal
           minimal_opt=ctrlplane_compute
           confirm_minimal_deployment
           ;;
        3) ocp_size=standard 
	   standard_opt=5node
           openshift4_standard_desc
           ;;
        4) ocp_size=local-storage
	   standard_opt=6node
           configure_local_storage
           ;;
        5) ocp_size=custom
           openshift4_custom_desc
           ;;
	6) reset_cluster_resources_default
	   ocp4_menu
	   ;;
        7) exit 0
                ;;
	*) printf "%s\n\n" " ${red}Error...${end}" && sleep 2
	esac
}

# ----------------------------------------------
# Step #3: Trap CTRL+C, CTRL+Z and quit singles
# ----------------------------------------------
trap '' SIGINT SIGQUIT SIGTSTP

# -----------------------------------
# Step #4: Main logic - infinite loop functions 
# ------------------------------------

function ocp4_menu(){
    if [[ ! -z ${INSTALLTYPE} ]]
    then
        if [ "A${INSTALLTYPE}" == "Anotmet" ]
        then
            printf "%s\n" "   ${cyn}Your hardware profile does not meet our minimal recommendation${end}"
            printf "%s\n" "   ${cyn}choose option 6 to customize the size cluster you want.${end}"
        else
            printf "%s\n\n" " ${cyn}Your hardware profile is ${INSTALLTYPE}${end}."
        fi

        user_choose_ocp4_profile

        printf "%s\n" ""
    fi
}


# -----------------------------------
# Step #4: Main Logic
# ------------------------------------

if [[ -f ${ocp_vars_file} ]]; then 
    ocp4_menu
elif [[ -f ${ocp3_vars_file} ]]; then 
    ocp3_menu
fi 


exit 0
