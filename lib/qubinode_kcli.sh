#!/bin/bash
# https://github.com/karmab/kcli
# This tool is meant to interact with existing virtualization providers (libvirt, KubeVirt, oVirt, OpenStack, VMware vSphere, GCP and AWS) and to easily deploy and customize VMs from cloud images.
# ./qubinode-installer -p kcli


setup_variables
product_in_use=kcli
source "${project_dir}/lib/qubinode_utils.sh"

############################################
## This  will determine the version of RHEL that is being used.
############################################

  RHEL_VERSION=$(get_rhel_version)
  if [[ $RHEL_VERSION == "FEDORA" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.11)/site-packages/kvirt/defaults.py"
  elif [[ $RHEL_VERSION == "RHEL8" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.6)/site-packages/kvirt/defaults.py"
  elif [[ $RHEL_VERSION == "ROCKY8" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.6)/site-packages/kvirt/defaults.py"

  elif [[ $(get_distro) == "centos" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.9)/site-packages/kvirt/defaults.py"
  else 
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.9)/site-packages/kvirt/defaults.py"
  fi 



############################################
## This is the file that contains the variables for the kvm host.
############################################
kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"

############################################
## This is the file that contains the variables for the common variables.
############################################
vars_file="${project_dir}/playbooks/vars/all.yml"
vault_vars_file="${project_dir}/playbooks/vars/vault.yml"


############################################
## @brief This function call the maintenance functions for kcli
############################################
qubinode_kcli_maintenance () {
    case ${product_maintenance} in
       configureimages)
	        kcli_configure_images
            ;;
       updatedefaults)
	        update_default_settings
            ;;
       createstaticprofile)
	        create_static_profile_ip
            ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}

############################################
## @brief This function will configure the images for kcli
##  * @param {string} $1 - The path to the vault file
############################################
function kcli_configure_images(){
    echo "Configuring images"
    echo "Downloading Fedora"
    sudo kcli download image fedora37
    echo "Downloading Centos Streams"
    sudo kcli download image centos9jumpbox -u https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-20221206.0.x86_64.qcow2
    sudo kcli download image  ztpfwjumpbox  -u https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-20221206.0.x86_64.qcow2
    sudo kcli download image centos8jumpbox -u https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-20220913.0.x86_64.qcow2
    sudo kcli download image centos8streams -u https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-20220913.0.x86_64.qcow2
    # sudo kcli download image ubuntu -u https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img
    RUN_ON_RHPDS=$(awk '/run_on_rhpds/ {print $2}' "${vars_file}")
    if [[ $(get_distro) == "rhel"  || "A${RUN_ON_RHPDS}" == "Ayes"  ]]; then
      echo "Downloading Red Hat Enterprise Linux 8"
      sudo kcli download image rhel8
      echo "Downloading Red Hat Enterprise Linux 9"
      echo "For AAP Deployments use: Red Hat Enterprise Linux 9.1 KVM Guest Image"
      sudo kcli download image rhel9
    fi

}

############################################
## Update the default settings for kcli
## @param {string} $1 - The path to the vault file
############################################
function update_default_settings(){
    if [ ! -f "${vault_key_file}" ]
    then
        printf "%s\n" " ${vault_key_file} does not exist"
        exit 1
    fi

    echo "Configuring default settings"
    if  [[ -f  ${defaults_file} ]];
    then
      decrypt_ansible_vault "${vault_vars_file}" > /dev/null
      rhsm_username=$(awk '/rhsm_username:/ {print $2}' "${vault_vars_file}")
      rhsm_password=$(awk '/rhsm_password:/ {print $2}' "${vault_vars_file}")
      encrypt_ansible_vault "${vaultfile}" >/dev/null
      sudo sed -i "s/^RHNUSER.*/RHNUSER = '"$rhsm_username"'/g" "${defaults_file}"
      sudo sed -i "s/^RHNPASSWORD.*/RHNPASSWORD = '"$rhsm_password"'/g" "${defaults_file}"
    else 
      echo "${defaults_file} not found exiting"
      exit 1
    fi  



    RUN_ON_RHPDS=$(awk '/run_on_rhpds/ {print $2}' "${vars_file}")
    ONE_RHEL=$(awk '/one_redhat/ {print $2}' "${vars_file}")
    if [ "A${RUN_ON_RHPDS}" == "Ayes" ];
    then
      KCLI_PROFILE=kcli-profiles-rhpds.yml
    elif  [ "A${ONE_RHEL}" == "Ayes" ];
    then
      KCLI_PROFILE=kcli-profiles-one-lab.yml
    else
      KCLI_PROFILE=kcli-profiles.yml
    fi
    
    if [ -f ${project_dir}/playbooks/vars/${KCLI_PROFILE} ];
    then
      cp "${project_dir}/playbooks/vars/${KCLI_PROFILE}" $HOME/qubinode-installer
    else 
      cp "${project_dir}/samples/${KCLI_PROFILE}" $HOME/qubinode-installer
    fi

    cp "${project_dir}/samples/files/ceph-cluster.yml" "${project_dir}/kcli_plans/ceph/ceph-cluster.yml"


    decrypt_ansible_vault "${vault_vars_file}" > /dev/null
    admin_username=$(awk '/admin_user:/ {print $2}' "${vars_file}")
    admin_password=$(awk '/admin_user_password:/ {print $2}' "${vault_vars_file}")
    rhsm_org=$(awk '/rhsm_org:/ {print $2}' "${vault_vars_file}")
    rhsm_activationkey=$(awk '/rhsm_activationkey:/ {print $2}' "${vault_vars_file}")
    rhsm_username=$(awk '/rhsm_username:/ {print $2}' "${vault_vars_file}")
    rhsm_password=$(awk '/rhsm_password:/ {print $2}' "${vault_vars_file}")
    encrypt_ansible_vault "${vaultfile}" >/dev/null
    sed -i "s/CHANGEUSER/${admin_username}/g" "${project_dir}/${KCLI_PROFILE}"
    sed -i "s/CHANGEPASSWORD/${admin_password}/g" "${project_dir}/${KCLI_PROFILE}"
    sed -i "s/CHANGEUSER/${admin_username}/g" "${project_dir}/kcli_plans/ceph/ceph-cluster.yml"
    sed -i "s/CHANGEPASSWORD/${admin_password}/g" "${project_dir}/kcli_plans/ceph/ceph-cluster.yml"
    sed -i "s/RHELORG/${rhsm_org}/g" "${project_dir}/${KCLI_PROFILE}"
    sed -i "s/ACTIVATIONKEY/${rhsm_activationkey}/g" "${project_dir}/${KCLI_PROFILE}"
    sed -i "s/RHELORG/${rhsm_org}/g" "${project_dir}/kcli_plans/ceph/ceph-cluster.yml"
    sed -i "s/ACTIVATIONKEY/${rhsm_activationkey}/g" "${project_dir}/kcli_plans/ceph/ceph-cluster.yml"
    sed -i "s/RHEL_USERNAME/${rhsm_username}/g" "${project_dir}/${KCLI_PROFILE}"
    sed -i "s/RHEL_PASSWORD/${rhsm_password}/g" "${project_dir}/${KCLI_PROFILE}"
    sed -i "s/RHEL_USERNAME/${rhsm_username}/g"  "${project_dir}/kcli_plans/ceph/ceph-cluster.yml"
    sed -i "s/RHEL_PASSWORD/${rhsm_password}/g"  "${project_dir}/kcli_plans/ceph/ceph-cluster.yml"
    if [ -f $HOME/offline_token ];
    then
      sed -i "s/CHANGEOFFLINETOKEN/$(cat $HOME/offline_token)/g" "${project_dir}/${KCLI_PROFILE}"
    fi

    tmp=$(sudo virsh net-list | grep "vyos-network-1" | awk '{ print $3}')
    if ([ "x$tmp" != "x" ] || [ "x$tmp" == "xyes" ])
    then
      read -p "vyos-network-1 network found. Would you like to configure all the vms yo use this network? " -n 1 -r
      echo    # (optional) move to a new line
      if [[ ! $REPLY =~ ^[Yy]$ ]]
      then
          sed -i "s/qubinet/vyos-network-1/g" "${project_dir}/${KCLI_PROFILE}"
          sed -i "s/qubinet/vyos-network-1/g"  "${project_dir}/kcli_plans/ceph/ceph-cluster.yml"
      fi
    fi 

    sudo mkdir -p /root/.kcli
    sudo cp "${project_dir}/${KCLI_PROFILE}" /root/.kcli/profiles.yml
    sudo mkdir -p ${HOME}/.kcli
    sudo cp "${project_dir}/${KCLI_PROFILE}" ${HOME}/.kcli/profiles.yml
    sudo rm -rf "${project_dir}/${KCLI_PROFILE}"
}

############################################################################################################
##  @description: Create a static ip for the vm deployed by kcli 
##  @param {string} kvm_host_vars_file
## @param {string} vault_vars_file
## @param {string} vars_file
##  @param {string} vaultfile
##  @return {string} kvm_host_gw
##  @return {string} kvm_host_netmask
## @return {string} vm_libvirt_net
##  @return {string} admin_username
## @return {string} admin_password
############################################################################################################
function create_static_profile_ip() {
    kvm_host_gw=$(awk '/kvm_host_gw:/ {print $2}' "${kvm_host_vars_file}")
    kvm_host_netmask=$(awk '/kvm_host_netmask:/ {print $2}' "${kvm_host_vars_file}")
    vm_libvirt_net=$(awk '/vm_libvirt_net:/ {print $2}' "${kvm_host_vars_file}")
    decrypt_ansible_vault "${vault_vars_file}" > /dev/null
    admin_username=$(awk '/admin_user:/ {print $2}' "${vars_file}")
    admin_password=$(awk '/admin_user_password:/ {print $2}' "${vault_vars_file}")
    encrypt_ansible_vault "${vaultfile}" >/dev/null


rhel8_static:
 image: rhel-8.7-x86_64-kvm.qcow2
 rhnregister: true
 numcpus: 2
 memory: 4096
 disks:
  - size: 20
 reservedns: true
 nets:
  - name: ${vm_libvirt_net}
    nic: eth0
    ip: 192.168.1.10
    mask: ${kvm_host_netmask}
    gateway: ${kvm_host_gw}
 cmds:
  - echo ${admin_password} | passwd --stdin root
  - useradd ${admin_username}
  - usermod -aG wheel ${admin_username}
  - echo "${admin_username} ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/${admin_username}
  - echo ${admin_password} | passwd --stdin ${admin_username}

}

############################################
## @brief This function will install and configure the default settings for kcli
############################################
function qubinode_setup_kcli() {
    if [[ ! -f /usr/bin/kcli ]];
    then 
        sudo dnf -y install libvirt libvirt-daemon-driver-qemu qemu-kvm
        sudo systemctl enable --now libvirtd
        sudo usermod -aG qemu,libvirt $USER
        if [[ $RHEL_VERSION == "CENTOS9" ]]; then
          sudo dnf copr enable karmab/kcli  epel-9-x86_64
        fi
        curl https://raw.githubusercontent.com/karmab/kcli/master/install.sh | bash
        echo "eval '$(register-python-argcomplete kcli)'" >> ~/.bashrc
        if [[ $RHEL_VERSION == "CENTOS9" ]]; then
          sudo kcli create host kvm -H 127.0.0.1 local
        fi
        update_default_settings
        kcli_configure_images
    else 
      echo "kcli is installed"
      kcli --help
    fi 
}
