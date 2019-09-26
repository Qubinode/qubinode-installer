function default_install () {
    product_opt="ocp"
    product=true
    printf "\n\n***********************\n"
    printf "* Running perquisites *\n"
    printf "***********************\n\n"
    qubinode_installer_preflight

    printf "\n\n********************************************\n"
    printf "* Ensure host system is registered to RHSM *\n"
    printf "*********************************************\n\n"
    qubinode_rhsm_register

    printf "\n\n*******************************************************\n"
    printf "* Ensure host system is setup as a ansible controller *\n"
    printf "*******************************************************\n\n"
    test ! -f /usr/bin/ansible && qubinode_setup_ansible

    printf "\n\n*********************************************\n"
    printf     "* Ensure host system is setup as a KVM host *\n"
    printf     "*********************************************\n"
    test ! -f /usr/bin/virsh && qubinode_setup_kvm_host

    #BRISDEIP=$(fconfig eno1 | grep inet |  grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | head -1)

    CHECKKVMIP=$(cat  ${project_dir}/playbooks/vars/all.yml | grep kvm_host_ip)
    if [[ -z  $CHECKKVMIP ]]; then
      if [[ ! -f ${project_dir}/playbooks/vars/kvm_host.yml ]]; then
        cp ${project_dir}/samples/kvm_host.yml ${project_dir}/playbooks/vars/kvm_host.yml
        bash lib/generate_all_yaml.sh kvm_host || exit 1
        qubinode_installer_preflight
        qubinode_setup_kvm_host
      fi
    fi
}

function idm_install() {

    printf "\n\n****************************\n"
    printf     "* Deploy VM for DNS server *\n"
    printf     "****************************\n"
    CHECKDNSVM=$(cat  ${project_dir}/playbooks/vars/all.yml | grep dns_server_vm)
    if [[ -z  $CHECKDNSVM ]]; then
      if [[ ! -f ${project_dir}/playbooks/vars/idm.yml ]]; then
        cp ${project_dir}/samples/idm.yml ${project_dir}/playbooks/vars/idm.yml
        bash lib/generate_all_yaml.sh idm || exit 1
        qubinode_installer_preflight
      fi
    fi
    productname=$(cat playbooks/vars/all.yml | grep product: | awk '{print $2}' | tr -d '"')
    CHECKFOR_DNS=$(sudo virsh list | grep running | grep ${productname}-dns  | wc -l)
    [[ $CHECKFOR_DNS -eq 0 ]] && qubinode_vm_manager deploy_dns

    printf "\n\n*****************************\n"
    printf     "* Install IDM on DNS server *\n"
    printf     "*****************************\n"
    qubinode_dns_manager server
}

function openshift3_install() {
  printf "\n\n******************************\n"
  printf     "* Deploy Nodes for ${product_opt} cluster *\n"
  printf     "******************************\n"
  if sudo virsh list|grep -E 'master|node|infra'
  then

    echo "Checking to see if Openshift is online."
    OCP_STATUS=$(curl --write-out %{http_code} --silent --output /dev/null " https://${productname}-master01.${domain}:8443" --insecure)
    if [[ $OCP_STATUS -eq 200 ]];  then
     echo "Openshift Console URL:  https://master.$domain:8443"
     exit 0
    else
      echo  "FAILED to connect to Openshift Console URL:  https://master.$domain:8443"
      qubinode_deploy_openshift
    fi
  else
      CHECKDNSVM=$(cat  ${project_dir}/playbooks/vars/all.yml | grep dns_server_vm)
      if [[ -z  $CHECKDNSVM ]]; then
        if [[ ! -f ${project_dir}/playbooks/vars/idm.yml ]]; then
          cp ${project_dir}/samples/idm.yml ${project_dir}/playbooks/vars/idm.yml
          bash lib/generate_all_yaml.sh idm || exit 1
          qubinode_installer_preflight
        fi
      fi
      openshift_config
      qubinode_vm_manager deploy_nodes
  fi

  OCUSER=$(cat ${project_dir}/playbooks/vars/all.yml | grep openshift_user: | awk '{print $2}')

  printf "\n\n*********************\n"
  printf     "*Deploy ${product_opt} cluster *\n"
  printf     "*********************\n"
  qubinode_deploy_openshift

  printf "\n\n*******************************************************\n"
  printf   "\nDeployment steps for ${product_opt} cluster is complete.\n"
  printf "\nCluster login: https://${productname}-master01.${domain}:8443\n"
  printf "     Username: ${OCUSER}\n"
  printf "     Password: <yourpassword>\n"
  printf "\n\nIDM DNS Server login: https://${productname}-dns01.${domain}\n"
  printf "     Username: admin\n"
  printf "     Password: <yourpassword>\n"
  printf "*******************************************************\n"
}
