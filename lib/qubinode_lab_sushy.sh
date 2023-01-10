#!/bin/bash

function sushy_variables () {
    setup_variables
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
    RHEL_VERSION=$(get_rhel_version)
}


function deploy_sushy_tools(){
  if [ ! -d "${HOME}/homelab" ]; then
    cd $HOME
    git clone https://github.com/kenmoini/homelab.git
    cd homelab/legacy/containers-as-a-service/caas-sushy

    export CONTAINER_NAME="sushy-tools"
    export CONTAINER_VOLUME_ROOT="/opt/service-containers/${CONTAINER_NAME}"
    sudo mkdir -p $CONTAINER_VOLUME_ROOT/config
    sudo cp config/sushy-emulator.conf  $CONTAINER_VOLUME_ROOT/config

    sudo ./scripts/service_init.sh start

    sudo firewall-cmd  --add-port=8111/tcp  --permanent
    sudo firewall-cmd --reload

    curl -v http://$(hostname -I | awk '{print $2}'| sed 's/ //g'):8111
  else
    printf "%s\n" "   ${blu}Sushy tools already exists${end}"
    printf "${yel}***************************${end}"
    printf "%s\n" 
    curl -v http://$(hostname -I | awk '{print $2}'| sed 's/ //g'):8111/redfish/v1/Systems/
    printf "%s\n" 
    printf "%s\n" "   ${blu}To remove sushy tools run the following command:${end}"
    printf "${yel}./qubinode-installer -p sushy_tools -m destroy_sushy_tools${end}"
  fi
}

function delete_vms(){
  if [ -f  $HOME/ocp4-ai-svc-universal/extras-create-sushy-bmh.yaml ]; then
    cd $HOME/ocp4-ai-svc-universal
    CLUSTER_NAME=$(yq -r  -o=json extras-create-sushy-bmh.yaml  | jq '.[].vars.cluster_name' | sed 's/"//g')
    NODES=$(yq -r  -o=json extras-create-sushy-bmh.yaml  | jq '.[].vars.virtual_bmh[].name' | sed 's/"//g')
    for node in $NODES; do
      sudo virsh destroy $CLUSTER_NAME-$node
      sudo virsh undefine $CLUSTER_NAME-$node
    done
  else
    echo "vms do not exist"
  fi

}

function destroy_sushy_tools(){
    delete_vms
    cd $HOME/homelab/legacy/containers-as-a-service/caas-sushy
    
    export CONTAINER_NAME="sushy-tools"
    export CONTAINER_VOLUME_ROOT="/opt/service-containers/${CONTAINER_NAME}"
    sudo ./scripts/service_init.sh stop
    sudo rm -rf ${HOME}/homelab
}

function create_vms(){
    if [ ! -d $HOME/ocp4-ai-svc-universal ]; then
        cd $HOME
        git clone https://github.com/tosin2013/ocp4-ai-svc-universal.git
        cd ocp4-ai-svc-universal
        sudo python3 -m pip install --upgrade -r requirements.txt
        sudo ansible-galaxy collection install -r collections/requirements.yml
        cat >credentials-infrastructure.yaml<<EOF
---
infrastructure_providers:
## Bare Metal Host Infrastructure Provider, sushy-tools virtual BMHs
- name: sushyBMH
  type: libvirt
  credentials:
    manufacturer: sushy
    ipmi_manufacturer: sushy
    ipmi_transport: http
    ipmi_endpoint: $(hostname -I | awk '{print $2}'| sed 's/ //g')
    ipmi_port: 8111

EOF

        cat credentials-infrastructure.yaml
        cp $HOME/qubinode-installer/samples/extras-create-sushy-bmh.yaml .
        tmp=$(sudo virsh net-list | grep "vyos-network-1" | awk '{ print $3}')
        if ([ "x$tmp" != "x" ] || [ "x$tmp" == "xyes" ])
        then
          sed -i "s/qubinet/vyos-network-1/g"  "extras-create-sushy-bmh.yaml"
          
        fi 
        if [[ $RHEL_VERSION == "RHEL8" ]]; then
          sudo ansible-galaxy collection install community.libvirt
          sudo ansible-playbook -e "@credentials-infrastructure.yaml" \
              --skip-tags=infra_libvirt_boot_vm,vmware_boot_vm,infra_libvirt_per_provider_setup,vmware_upload_iso \
              extras-create-sushy-bmh.yaml -e ansible_python_interpreter=/usr/bin/python3
        else
                  sudo ansible-galaxy collection install community.libvirt
          sudo ansible-playbook -e "@credentials-infrastructure.yaml" \
              --skip-tags=infra_libvirt_boot_vm,vmware_boot_vm,infra_libvirt_per_provider_setup,vmware_upload_iso \
              extras-create-sushy-bmh.yaml
        fi 
    else
        cd $HOME/ocp4-ai-svc-universal
        if [[ $RHEL_VERSION == "RHEL8" ]]; then
          sudo python3.9 -m pip install --upgrade -r requirements.txt
          sudo ansible-galaxy collection install community.libvirt
          sudo ansible-playbook -e "@credentials-infrastructure.yaml" \
              --skip-tags=infra_libvirt_boot_vm,vmware_boot_vm,infra_libvirt_per_provider_setup,vmware_upload_iso \
              extras-create-sushy-bmh.yaml -e ansible_python_interpreter=/usr/bin/python3
        else
          sudo ansible-galaxy collection install community.libvirt
          sudo ansible-playbook -e "@credentials-infrastructure.yaml" \
              --skip-tags=infra_libvirt_boot_vm,vmware_boot_vm,infra_libvirt_per_provider_setup,vmware_upload_iso \
              extras-create-sushy-bmh.yaml
        fi 
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
           delete_vms
           ;;
        destroy_sushy_tools)
           sushy_variables
           echo "Destorying vms and sushy tools"
           destroy_sushy_tools
           ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}
