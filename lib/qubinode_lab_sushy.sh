#!/bin/bash

function sushy_variables () {
    setup_variables
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
}


function deploy_sushy_tools(){
  if [ ! -d "${HOME}/sushy-tools" ]; then
    cd $HOME
    git clone https://github.com/kenmoini/homelab.git
    cd homelab/legacy/containers-as-a-service/caas-sushy

    export CONTAINER_NAME="sushy-tools"
    export CONTAINER_VOLUME_ROOT="/opt/service-containers/${CONTAINER_NAME}"
    sudo mkdir -p $CONTAINER_VOLUME_ROOT/config
    sudo cp config/sushy-emulator.conf  $CONTAINER_VOLUME_ROOT/config

    ./scripts/service_init.sh start

    sudo firewall-cmd  --add-port=8111/tcp  --permanent
    sudo firewall-cmd --reload

    curl -v http://$(hostname -I | awk '{print $2}'| sed 's/ //g'):8111
  else
    echo "Sushy tools already exists"
    echo "To remove sushy tools run the following command:"
    echo "./qubinode-installer -p sushy_tools -m destroy_sushy_tools"
    curl -v http://$(hostname -I | awk '{print $2}'| sed 's/ //g'):8111/redfish/v1/Systems/
  fi
}

function delete_vms(){
  echo "delete vms"
}

function destroy_sushy_tools(){
    delete_vms
    cd homelab/legacy/containers-as-a-service/caas-sushy
    
    export CONTAINER_NAME="sushy-tools"
    export CONTAINER_VOLUME_ROOT="/opt/service-containers/${CONTAINER_NAME}"
     ./scripts/service_init.sh remove
    rm -rf $CONTAINER_VOLUME_ROOT
}

function create_vms(){
    if [ ! -d $HOME/ocp4-ai-svc-universal ]; then
        cd $HOME
        git clone
    else
        cd $HOME/ocp4-ai-svc-universal
    fi 
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
