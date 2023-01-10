#!/bin/bash

function tempalte_variables () {
    setup_variables
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
    RHEL_VERSION=$(get_rhel_version)
}


function create(){
  echo "creating template"
}

function destroy(){
  echo "destorying template"
}


function tempalte_tools_maintenance(){
    echo "Run the following commands"
    case ${product_maintenance} in
       create)
           tempalte_variables
           echo "Deploying tempalte"
           create
           ;;
        destroy)
           tempalte_variables
           echo "detroying  tempalte"
           destroy
           ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}
