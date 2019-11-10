#!/bin/bash
# A menu driven shell script sample template
## ----------------------------------
# Step #1: Define variables
# ----------------------------------
EDITOR=vim
PASSWD=/etc/passwd
RED='\033[0;41;30m'
STD='\033[0;0;39m'

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
openshift_size_vars_file="${project_dir}/playbooks/vars/openshift3_size.yml"

if [[ -z $1 ]]; then
  echo "No Flag has been passed. "
  exit 1
fi

arr=('minimal', 'minimal_cns', 'standard', 'performnance')
match=$(echo "${arr[@]:0}" | grep -o $1)
if [[ ! -z $match ]];  then
  echo ""
else
  echo "Incorrect flag has been passed. "
  echo "Valid flags are  minimal, minimal_cns, standard, performnance"
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
EOF
}

function minimal_cns_desc() {
cat << EOF
======================
Deployment Type: Minimal CNS
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
    cp -f ${project_dir}/samples/ocp_vm_sizing/minimal.yml ${openshift_size_vars_file}
    exit 0
  fi

}

minimal_cns_deployment(){
	minimal_cns_desc
  read -p "Are you sure? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    show_menus
    read_options
  else
    cp -f ${project_dir}/samples/ocp_vm_sizing/minimal_cns.yml ${openshift_size_vars_file}
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
    cp -f ${project_dir}/samples/ocp_vm_sizing/perfomance.yml ${openshift_size_vars_file}
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
    cp -f ${project_dir}/samples/ocp_vm_sizing/standard.yml ${openshift_size_vars_file}
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
  echo "2. Minimal CNS Deployment"
  echo "3. Standard Deployment"
	echo "4. Performance Deployment"
	echo "5. Exit"
}

read_options(){
	local choice
	read -p "Enter choice [ 1 - 5] " choice
	case $choice in
		1) minimal_deployment ;;
		2) minimal_cns_deployment ;;
    3) standard_deployment ;;
    4) perfomance_deployment;;
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

echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo "openshift_auto_install: $openshift_auto_install"
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
exit
if [ "A${openshift_auto_install}" != "Atrue" ]
then
    if [[ ! -z ${INSTALLTYPE} ]]
    then
        echo "Your Deployment is ${INSTALLTYPE}"
        echo "This will deploy the following. "
        case $1 in
            minimal) minimal_desc ;;
            minimal_cns) minimal_cns_desc ;;
            standard) standard_desc ;;
            performance) performance_desc ;;
            *) exit 0;;
        esac

        read -p "Would you like a customize this deployment? " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            case $INSTALLTYPE in
                minimal) minimal_deployment;;
                minimal_cns) minimal_cns_deployment;;
                standard) standard_deployment;;
                performance) performance_deployment;;
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
    echo "COPY STANDARD*********************"
    exit
    cp -f ${project_dir}/samples/ocp_vm_sizing/standard.yml ${openshift_size_vars_file}
fi

exit 0
