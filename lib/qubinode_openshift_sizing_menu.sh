#!/bin/bash
# A menu driven shell script sample template
## ----------------------------------
# Step #1: Define variables
# ----------------------------------
EDITOR=vim
PASSWD=/etc/passwd
RED='\033[0;41;30m'
STD='\033[0;0;39m'
ocp3_vars_file="${playbooks_dir}/vars/ocp3.yml"

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
source "${project_dir}/lib/qubinode_installer_prereqs.sh"
source "${project_dir}/lib/qubinode_utils.sh"
source "${project_dir}/lib/qubinode_requirements.sh"

qubinode_required_prereqs
auto_install=$(awk '/^openshift_auto_install:/ {print $2}' "${ocp3_vars_file}")


if [[ -z $1 ]]; then
  echo "No Flag has been passed. "
  exit 1
fi

arr=('minimal', 'small', 'standard', 'performnance')
match=$(echo "${arr[@]:0}" | grep -o $1)

if [[ ! -z $match ]];  then
  echo ""
else
  echo "Incorrect flag has been passed. "
  echo "Valid flags are  minimal, small, standard, performnance"
  exit 1
fi

INSTALLTYPE=${1}


function minimal_desc() {
cat << EOF
======================
Deployment Type: Minimal
======================
1 master
1 infra
1 worker

========
Features
========
Openshift Operators: False
Hawkular Metrics: False
ELK logging: False
Promethous: False
Gluster: False
EOF
}

function small_desc() {
cat << EOF
======================
Deployment Type: Small
Deployment will contain Container Native Storage
======================
1 master
2 infra
2 worker

========
Features
========
Openshift Operators: False
Hawkular Metrics: False
ELK logging: False
Promethous: False

EOF
}

function performance_desc() {
cat << EOF
======================
Deployment Type: Performance
======================
3 master
0 infra
2 worker
1 lb

========
Features
========
Openshift Operators: True
Hawkular Metrics: True
ELK logging: True
Promethous: True
EOF
}

function standard_desc() {
cat << EOF
======================
Deployment Type: Standard
======================
1 master
2 infra
2 worker

========
Features
========
Openshift Operators: True
Hawkular Metrics: True
ELK logging: False
Promethous: True
EOF
}


# ----------------------------------
# Step #2: User defined function
# ----------------------------------
pause(){
  read -p "Press [Enter] key to continue..." fackEnterKey
}


minimal_deployment(){
	minimal_desc
  read -p "Are you sure? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    show_menus
    read_options
  else
    echo "Setting OpenShift Deployment size to $ocp_size"
    sed -i "s/openshift_deployment_size:.*/openshift_deployment_size: $ocp_size/g" "${ocp3_vars_file}"
    openshift_size_vars_file="${project_dir}/playbooks/vars/openshift3_size_${ocp_size}.yml"
    cp -f ${project_dir}/samples/ocp_vm_sizing/${ocp_size}.yml ${openshift_size_vars_file}
    exit 0
  fi

}

small_deployment(){
	small_desc
  read -p "Are you sure? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    show_menus
    read_options
  else
    echo "Setting OpenShift Deployment size to $ocp_size"
    sed -i "s/openshift_deployment_size:.*/openshift_deployment_size: $ocp_size/g" "${ocp3_vars_file}"
    openshift_size_vars_file="${project_dir}/playbooks/vars/openshift3_size_${ocp_size}.yml"
    cp -f ${project_dir}/samples/ocp_vm_sizing/${ocp_size}.yml ${openshift_size_vars_file}
    exit 0
  fi
}

perfomance_deployment(){
	performance_desc
  read -p "Are you sure? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    show_menus
    read_options
  else
    echo "Setting OpenShift Deployment size to $ocp_size"
    sed -i "s/openshift_deployment_size:.*/openshift_deployment_size: $ocp_size/g" "${ocp3_vars_file}"
    openshift_size_vars_file="${project_dir}/playbooks/vars/openshift3_size_${ocp_size}.yml"
    cp -f ${project_dir}/samples/ocp_vm_sizing/${ocp_size}.yml ${openshift_size_vars_file}
    exit 0
  fi

}

standard_deployment(){
	standard_desc
  read -p "Are you sure? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    show_menus
    read_options
  else
    echo "Setting OpenShift Deployment size to $ocp_size"
    sed -i "s/openshift_deployment_size:.*/openshift_deployment_size: $ocp_size/g" "${ocp3_vars_file}"
    openshift_size_vars_file="${project_dir}/playbooks/vars/openshift3_size_${ocp_size}.yml"
    cp -f ${project_dir}/samples/ocp_vm_sizing/${ocp_size}.yml ${openshift_size_vars_file}
    exit 0
  fi

}
# function to display menus
show_menus() {
	clear
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo " Qubinode OpenShift Profiles"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "1. Minimal Deployment"
        echo "2. Small Deployment"
        echo "3. Standard Deployment"
	echo "4. Performance Deployment"
	echo "5. Exit"
}

read_options(){
	local choice
	read -p "Enter choice [ 1 - 5] " choice
	case $choice in
		1) ocp_size=minimal
                   minimal_deployment ;;
		2) ocp_size=small
                   small_deployment ;;
                3) ocp_size=standard
                   standard_deployment ;;
                4) ocp_size=performance
                   perfomance_deployment;;
		5) exit 0;;
		*) echo -e "${RED}Error...${STD}" && sleep 2
	esac
}

# ----------------------------------------------
# Step #3: Trap CTRL+C, CTRL+Z and quit singles
# ----------------------------------------------
trap '' SIGINT SIGQUIT SIGTSTP

# -----------------------------------
# Step #4: Main logic - infinite loop
# ------------------------------------

if [ "A${auto_install}" != "Atrue" ]
then
    if [[ ! -z ${INSTALLTYPE} ]]
    then
        echo "Your Deployment is ${INSTALLTYPE}"
        echo "This will deploy the following. "
        case "${INSTALLTYPE}" in
            #minimal) minimal_desc ;;
            #small) small_desc ;;
            #standard) standard_desc ;;
            #performance) performance_desc ;;
            minimal)
                         minimal_desc
                         ;;
            small)
                         small_desc
                         ;;
            standard)
                         standard_desc
                         ;;
            performance)
                         performance_desc
                         ;;

            *) exit 0;;
        esac

        read -p "Would you like a customize this deployment? " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            case $INSTALLTYPE in
            minimal)
                         ocp_size=minimal
                         echo "*** RUNNING SIZE $ocp_size ***"
                         minimal_deployment
                         ;;
            small)
                         ocp_size=small
                         echo "*** RUNNING SIZE $ocp_size ***"
                         small_deployment
                         ;;
            standard)
                         ocp_size=standard
                         echo "*** RUNNING SIZE $ocp_size ***"
                         standard_deployment
                         ;;
            performance)
                         ocp_size=performance
                         echo "*** RUNNING SIZE $ocp_size ***"
                         performance_deployment
                         ;;
                *) exit 0;;
            esac
        else
            while true
            do
                show_menus
                read_options
            done
        fi
    fi
else
    ocp_size="standard"
    sed -i "s/openshift_deployment_size:.*/openshift_deployment_size: $ocp_size/g" "${ocp3_vars_file}"
    openshift_size_vars_file="${project_dir}/playbooks/vars/openshift3_size_${ocp_size}.yml"
    cp -f ${project_dir}/samples/ocp_vm_sizing/${ocp_size}.yml ${openshift_size_vars_file}
fi

clear
echo HERE
echo "ocp_size=$ocp_size"

exit

exit 0
