#!/bin/bash

function ai_sno_variables () {
    setup_variables
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
    RHEL_VERSION=$(get_rhel_version)
}


function create(){
  echo "creating SNO  deoployment using assisted installer"
  echo "https://docs.openshift.com/container-platform/4.9/installing/installing_sno/install-sno-installing-sno.html"
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
