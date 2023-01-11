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
    echo "Please download the pull secret from https://cloud.redhat.com/openshift/install/pull-secret"
    echo "and save it to vim $HOME/ocp-pull-secret"
    exit 1
  fi

  if [ ! -f $HOME/.ssh/id_rsa.pub ];
  then 
    echo "Please create a ssh key and save it to $HOME/.ssh/id_rsa.pub"
    exit 1
  fi

  if [ ! -f $HOME/rh-api-offline-token ];
  then 
    echo "Please download the offline token from https://access.redhat.com/management/api"
    echo "and save it to vim  $HOME/rh-api-offline-token"
    exit 1
  fi

}
function create(){
  echo "creating SNO  deoployment using assisted installer"
  echo "https://docs.openshift.com/container-platform/latest/installing/installing_sno/install-sno-installing-sno.html"
  check_dependencies

  if [ ! -d $HOME/ocp4-ai-svc-universal ];
  then 
    cd $HOME
    git clone https://github.com/tosin2013/ocp4-ai-svc-universal.git
    cd $HOME/ocp4-ai-svc-universal
    python3 -m pip install --upgrade -r requirements.txt
    ansible-galaxy collection install -r collections/requirements.yml
  fi 

        cat >credentials-infrastructure.yaml<<EOF
---
infrastructure_providers:
## KVM/Libvirt Infrastructure Provider, local host
- name: ai-libvirt
  type: libvirt
  credentials:
    libvirt_options: ""
  configuration:
    # libvirt_username needs permission to write to target paths
    libvirt_base_iso_path: /var/lib/libvirt/images
    libvirt_base_vm_path: /var/lib/libvirt/images
    libvirt_network:
      # type: bridge | network
      type: network
      name: lanBridge
      model: virtio

EOF

if [ ! -f $HOME/ocp4-ai-svc-universal/*-cluster-config-libvirt.yaml ];
then 
    read -p "Enter the cluster size Options: full|sno|converged:" cluster_size
    read -p "Enter  the network type static|dhcp: " network_type

    if [ $cluster_size != "full" ] || [ $cluster_size != "sno" ] || [ $cluster_size != "converged" ];
    then
        echo "deploying cluster"
    else 
        echo "Incorrect cluster size"
        echo "Options full|sno|converged"
        exit 1
    fi

    if [[ $network_type == "static" || $network_type == "dhcp" ]];
    then
        cp ${project_dir}/samples/ocp4-ai-svc-universal/${network_type}/${cluster_size}-cluster-config-libvirt.yaml .
    else
      echo "Invalid network type"
      exit 1
    fi
fi



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
