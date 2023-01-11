#!/bin/bash

function ai_sno_variables () {
    setup_variables
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
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


function test_dns(){
    cd $HOME/ocp4-ai-svc-universal
    LIBVIRT_CONFIG=$(ls *cluster-config-libvirt.yaml)
    if [ -z $LIBVIRT_CONFIG ];
    then 
      echo "No libvirt config file found"
      exit 1
    fi

    CLUSTER_API_VIP=$(yq -r  -o=json  $LIBVIRT_CONFIG | jq '.cluster_api_vip' | sed 's/"//g')
    CLUSTER_INGRESS_VIP=$(yq -r  -o=json  $LIBVIRT_CONFIG | jq '.cluster_apps_vip' | sed 's/"//g')
    CLUSTER_BASE_DNS=$(yq -r  -o=json  $LIBVIRT_CONFIG | jq '.cluster_domain' | sed 's/"//g')
    CLUSTER_NAME=$(yq -r  -o=json  $LIBVIRT_CONFIG | jq '.cluster_name' | sed 's/"//g')
    TEST_CLUSTER_INGRESS_VIP=$(dig +short test.apps.${CLUSTER_NAME}.${CLUSTER_BASE_DNS} |  grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" |  head -1)
    TEST_CLUSTER_API_VIP=$(dig +short api.${CLUSTER_NAME}.${CLUSTER_BASE_DNS} |  grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" |  head -1)
    
    if [ -z $TEST_CLUSTER_INGRESS_VIP ];
    then 
      echo "TEST_CLUSTER_INGRESS_VIP: test.apps.${CLUSTER_NAME}.${CLUSTER_BASE_DNS}  was not found on dns record"
      exit 1
    fi

    if [ -z $TEST_CLUSTER_API_VIP ];
    then 
      echo "TEST_CLUSTER_API_VIP:  api.${CLUSTER_NAME}.${CLUSTER_BASE_DNS}  was not found on dns record"
      exit 1
    fi

    echo "Current CLUSTER_INGRESS_VIP=${CLUSTER_INGRESS_VIP}"
    echo -e "===== Testing CLUSTER_INGRESS_VIP..."

    if [ ${CLUSTER_INGRESS_VIP} != ${TEST_CLUSTER_INGRESS_VIP} ];
    then
      echo "Please check CLUSTER_INGRESS_VIP"
      echo "Reported CLUSTER_INGRESS_VIP $CLUSTER_INGRESS_VIP "
      echo "Reported CLUSTER_INGRESS_VIP $TEST_CLUSTER_INGRESS_VIP "
      exit 1
    else
      echo "CLUSTER_INGRESS_VIP $CLUSTER_INGRESS_VIP is valid"
    fi 

    echo "Current CLUSTER_API_VIP=${CLUSTER_API_VIP}"
    echo -e "===== Testing CLUSTER_API_VIP..."

    if [ ${CLUSTER_API_VIP} != ${TEST_CLUSTER_API_VIP} ];
    then 
      echo "Please check CLUSTER_API_VIP"
      echo "Reported CLUSTER_API_VIP $CLUSTER_API_VIP "
      echo "Reported CLUSTER_API_VIP $TEST_CLUSTER_API_VIP "
      exit 1
    else
      echo "CLUSTER_API_VIP $CLUSTER_API_VIP is valid"
    fi 


}

function validate_env(){
  cd $HOME/ocp4-ai-svc-universal
  LIBVIRT_CONFIG=$(ls *cluster-config-libvirt.yaml)
  if [ -z $LIBVIRT_CONFIG ];
  then 
    echo "No libvirt config file found"
    exit 1
  fi
  
  cluster_api_vip=$(yq -r  -o=json  $LIBVIRT_CONFIG | jq '.cluster_api_vip' | sed 's/"//g')
  cluster_apps_vip=$(yq -r  -o=json  $LIBVIRT_CONFIG | jq '.cluster_apps_vip' | sed 's/"//g')
  echo "Check if the cluster_api_vip $cluster_api_vip is reachable"
  if ping -c 1 $cluster_api_vip &> /dev/null
  then
    echo "$cluster_api_vip reachable exiting with the deployment"
    exit 
  else
    echo "$cluster_api_vip  not reachable continuing with the deployment"
  fi
  echo "Check if the cluster_apps_vip $cluster_apps_vip is reachable"
  if ping -c 1 $cluster_apps_vip &> /dev/null
  then
    echo "$cluster_apps_vip reachable exiting with the deployment"
    exit 
  else
    echo "$cluster_apps_vip  not reachable continuing with the deployment"
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
      type: bridge
      name: qubibr0
      model: virtio
EOF

if [ ! -f $HOME/ocp4-ai-svc-universal/*-cluster-config-libvirt.yaml ];
then 
    cd $HOME/ocp4-ai-svc-universal
    read -p "Enter the cluster size Options: full|sno|converged: " cluster_size
    read -p "Enter  the network type static|dhcp: " network_type

    if [ $cluster_size == "full" ] || [ $cluster_size == "sno" ] || [ $cluster_size == "converged" ];
    then
        echo "deploying cluster test"
    else 
        echo "Incorrect cluster size"
        echo "Options full|sno|converged"
        exit 1
    fi

    if [[ $network_type == "static" || $network_type == "dhcp" ]];
    then
        cp ${project_dir}/samples/ocp4-ai-svc-universal/${network_type}/${cluster_size}-cluster-config-libvirt.yaml .
        
        domain=$(awk '/domain:/ {print $2}' "${vars_file}")    
        sed -i "s/cluster_domain:.*/cluster_domain: $domain/g" ${cluster_size}-cluster-config-libvirt.yaml 

        if [ $network_type == "static" ];
        then 
           openshift_network_octect=$(awk '/openshift_network_octect:/ {print $2}' "${vars_file}")    
           sed -i "s/192.168.11/${openshift_network_octect}/g" ${cluster_size}-cluster-config-libvirt.yaml 
        fi 
        validate_env
        test_dns
        #ansible-playbook -e "@${cluster_size}-cluster-config-libvirt.yaml" -e "@credentials-infrastructure.yaml" bootstrap.yaml
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
