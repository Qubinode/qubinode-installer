#!/bin/bash
# A menu driven shell script sample template
## ----------------------------------
# Step #1: Define variables
# ----------------------------------
EDITOR=vim
PASSWD=/etc/passwd
RED='\033[0;41;30m'
STD='\033[0;0;39m'
project_dir_path=$(sudo find / -type d -name qubinode-installer)
project_dir=$project_dir_path
echo ${project_dir}
project_dir="`( cd \"$project_dir_path\" && pwd )`"


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

confirm(){
  read -p "Are you sure? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
      exit 0
  fi
}

minimal_deployment(){
	minimal_desc
  if [[ -z $1 ]]; then
    confirm
  fi
  cat ${project_dir}/samples/ocp_vm_sizing/minimal.yml >> ${project_dir}/playbooks/vars/all.yml
}

minimal_cns_deployment(){
	minimal_cns_desc
  if [[ -z $1 ]]; then
    confirm
  fi
  cat ${project_dir}/samples/ocp_vm_sizing/minimal_cns.yml >> ${project_dir}/playbooks/vars/all.yml
}

perfomance_deployment(){
	perfomance_desc
  if [[ -z $1 ]]; then
    confirm
  fi
  cat ${project_dir}/samples/ocp_vm_sizing/perfomance.yml >> ${project_dir}/playbooks/vars/all.yml
}

standard_deployment(){
	standard_desc
  if [[ -z $1 ]]; then
    confirm
  fi
  cat ${project_dir}/samples/ocp_vm_sizing/standard.yml >> ${project_dir}/playbooks/vars/all.yml
}
# function to display menus
show_menus() {
	clear
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo " Qubinode OpenShift Profiles"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "1. Minimal Deployment"
  echo "2. Medium Deployment"
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
if [[ ! -z ${1} ]]; then
  echo "Your Deployment is ${1}"
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
  if [[ $REPLY =~ ^[Yy]$ ]]
  then

    while true
    do
    	show_menus
    	read_options
    done

  else
    case $1 in
      minimal) minimal_deployment confirm ;;
      minimal_cns) minimal_cns_deployment confirm ;;
      standard) standard_deployment confirm ;;
      performance) performance_deployment confirm ;;
      *) exit 0;;
    esac
  fi
fi
