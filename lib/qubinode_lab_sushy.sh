#!/bin/bash

function sushy_variables () {
    setup_variables
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
}


function deploy_sushy_tools(){
  echo "deploy sushy tools"
}

function destroy_sushy_tools(){
  echo "destroy sushy tools"
}

function create_vms(){
  echo "create vms"
}


function sushy_tools_maintenance(){
    echo "Run the following commands"
    case ${product_maintenance} in
       create)
           sushy_variables
           echo "Deploying sushy tools"
           deploy_sushy_tools
           ;;
        create_vms)
           sushy_variables
           echo "Deploying vms"
           create_vms
           ;;
       destroy_vms)
           sushy_variables
           echo "Destorying vms"
           destroy_router
           ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}
