#!/bin/bash

function ai_sno_variables () {
    setup_variables
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
    RHEL_VERSION=$(get_rhel_version)
}


function check_dependencies(){
  echo "checking dependencies"
  if [ ! -f $HOME/ocp-pull-secret ];
  then 
    echo "Please download the pull secret from hhttps://cloud.redhat.com/openshift/install/pull-secret"
    echo "and save it to $HOME/ocp-pull-secret"
    exit 1
  fi

  if [ ! -f $HOME/ssh_key.pub ];
  then 
    echo "Please create a ssh key and save it to $HOME/ssh_key.pub"
    exit 1
  fi

  if [ ! -f $HOME/rh-api-offline-token ];
  then 
    echo "Please download the offline token from https://access.redhat.com/management/api"
    echo "and save it to $HOME/rh-api-offline-token"
    exit 1
  fi
}
function create(){
  echo "creating SNO  deoployment using assisted installer"
  echo "https://docs.openshift.com/container-platform/4.9/installing/installing_sno/install-sno-installing-sno.html"
  check_dependencies
}

function destroy(){
  echo "destorying SNO  deoployment using assisted installer"
}


function ai_sno_tools_maintenance(){
    echo "Run the following commands"
    case ${product_maintenance} in
       create)
           ai_sno_variables
           echo "Deploying  SNO using assisted installer"
           create
           ;;
        destroy)
           ai_sno_variables
           echo "Destroying sno instance"
           destroy
           ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}
