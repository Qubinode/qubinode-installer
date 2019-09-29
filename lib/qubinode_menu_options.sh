function default_install () {
    product_opt=${1}
    product=true
    printf "\n\n***********************\n"
    printf "* Running prerequistes *\n"
    printf "***********************\n\n"
    qubinode_installer_preflight ${product_opt}

    printf "\n\n********************************************\n"
    printf "* Ensure host system is registered to RHSM *\n"
    printf "*********************************************\n\n"
    qubinode_rhsm_register

    printf "\n\n*******************************************************\n"
    printf "* Ensure host system is setup as a ansible controller *\n"
    printf "*******************************************************\n\n"
    test ! -f /usr/bin/ansible && qubinode_setup_ansible

    ROLES_DIR="${project_dir}/playbooks/roles"
    TOTAL=$(ls -lsth  $ROLES_DIR | awk '{print $10}'  | wc -l)

    if [[ ${TOTAL} -le 10 ]]; then
      qubinode_setup_ansible
    fi

    printf "\n\n*********************************************\n"
    printf     "* Ensure host system is setup as a KVM host *\n"
    printf     "*********************************************\n"
    test ! -f /usr/bin/virsh && qubinode_setup_kvm_host
    BRIDGEIP=$(ifconfig qubibr0 | grep inet |  grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | head -1)
    if [[ -z $BRIDGEIP ]]; then
      qubinode_setup_kvm_host
    fi

    CHECKKVMIP=$(cat  ${project_dir}/playbooks/vars/all.yml | grep kvm_host_ip)
    if [[ -z  $CHECKKVMIP ]]; then
      if [[ ! -f ${project_dir}/playbooks/vars/kvm_host.yml ]]; then
        cp ${project_dir}/samples/kvm_host.yml ${project_dir}/playbooks/vars/kvm_host.yml
        bash lib/generate_all_yaml.sh kvm_host || exit 1
        qubinode_installer_preflight ${product_opt}
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
        qubinode_installer_preflight ${product_opt}
      fi
    fi

    CHECKFOR_DNS=$(sudo virsh list | grep running | grep qbn-dns  | wc -l)
    [[ $CHECKFOR_DNS -eq 0 ]] && qubinode_vm_manager deploy_dns

    printf "\n\n*****************************\n"
    printf     "* Install IDM on DNS server *\n"
    printf     "*****************************\n"
    qubinode_dns_manager server

    if [[ $product_opt == "idm" ]]; then
      domain=$(awk '/^domain:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
      productname=$(awk '/^product:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
      printf "*******************************************************\n"
      printf "\n\nIDM DNS Server login: https://${productname}-dns01.${domain}\n"
      printf "     Username: admin\n"
      printf "     Password: <yourpassword>\n"
      printf "*******************************************************\n"
    fi

}

function openshift3_install() {
  printf "\n\n******************************\n"
  printf     "* Deploy Nodes for ${product_opt} cluster *\n"
  printf     "******************************\n"
  domain=$(awk '/^domain:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
  ssh_username=$(awk '/^admin_user:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
  ocp_user=$(awk '/^openshift_user:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
  productname=$(awk '/^product:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")

  if sudo virsh list|grep -E 'master|node|infra'
  then

    echo "Checking to see if Openshift is online."
    OCP_STATUS=$(curl --write-out %{http_code} --silent --output /dev/null " https://${productname}-master01.${domain}:8443" --insecure)
    if [[ $OCP_STATUS -eq 200 ]];  then
     echo "Openshift Console URL:  https://master.$domain:8443"
     exit 0
    else
      CHECKFOROCP=$(sudo virsh list|grep -E 'ocp-master' | awk '{print $2}')
      if [[ $CHECKFOROCP == "ocp-master01" ]]; then
        if [[ ${productname} == "okd" ]]; then
          echo "Please destroy running OpenShift Enterprise VMs before continuing to install OpenShift Origin."
          echo "********************************************"
          echo "1. ./qubinode-installer -p ocp -d or ./qubinode-installer -p ocp -m deploy_nodes -d "
          echo "2. ./qubinode-installer -p idm -d "
          echo "3. ./qubinode-installer -p ocp -m clean "
          echo "restart ./qubinode-installer option 2"
          exit 1
        fi
      fi
      echo  "FAILED to connect to Openshift Console URL:  https://master.$domain:8443"
      printf "\n\n*********************\n"
      printf     "*Deploy ${product_opt} cluster *\n"
      printf     "*********************\n"
      qubinode_vm_manager deploy_nodes
      qubinode_deploy_openshift
    fi
  else
      CHECKDNSVM=$(cat  ${project_dir}/playbooks/vars/all.yml | grep dns_server_vm)
      if [[ -z  $CHECKDNSVM ]]; then
        if [[ ! -f ${project_dir}/playbooks/vars/idm.yml ]]; then
          cp ${project_dir}/samples/idm.yml ${project_dir}/playbooks/vars/idm.yml
          bash lib/generate_all_yaml.sh idm || exit 1
          qubinode_installer_preflight ${product_opt}
        fi
      fi
      openshift_config
      qubinode_vm_manager deploy_nodes

      printf "\n\n*********************\n"
      printf     "*Deploy ${product_opt} cluster *\n"
      printf     "*********************\n"
      qubinode_deploy_openshift
  fi

  OCUSER=$(cat ${project_dir}/playbooks/vars/all.yml | grep openshift_user: | awk '{print $2}')



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
