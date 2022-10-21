#!/bin/bash

setup_variables
product_in_use=kcli
source "${project_dir}/lib/qubinode_utils.sh"

  RHEL_VERSION=$(get_rhel_version)
  if [[ $RHEL_VERSION == "FEDORA" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.10)/site-packages/kvirt/defaults.py"
  elif [[ $RHEL_VERSION == "RHEL8" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.6)/site-packages/kvirt/defaults.py"
  elif [[ $RHEL_VERSION == "ROCKY8" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.6)/site-packages/kvirt/defaults.py"
    RUN_ON_RHPDS=$(awk '/run_on_rhpds/ {print $2}' "${vars_file}")
  elif [[ $(get_distro) == "centos" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.9)/site-packages/kvirt/defaults.py"
  else 
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.9)/site-packages/kvirt/defaults.py"
  fi 



kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
vars_file="${project_dir}/playbooks/vars/all.yml"
vault_vars_file="${project_dir}/playbooks/vars/vault.yml"
vg_name=$(cat "${kvm_host_vars_file}"| grep vg_name: | awk '{print $2}')
requested_brigde=$(cat "${kvm_host_vars_file}"|grep  vm_libvirt_net: | awk '{print $2}' | sed 's/"//g')

function qubinode_kcli_maintenance () {
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

function kcli_configure_images(){
    echo "Configuring images"
    echo "Downloading Fedora"
    sudo kcli download image fedora36
    echo "Downloading Centos Streams"
    sudo kcli download image centos9jumpbox -u https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-20220919.0.x86_64.qcow2
    sudo kcli download image  ztpfwjumpbox  -u https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-20220919.0.x86_64.qcow2 
    sudo kcli download image centos8jumpbox -u https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-20220125.1.x86_64.qcow2
    if [ $(get_distro) == "rhel"  || ${RUN_ON_RHPDS} == "yes" ]; then
      echo "Downloading Red Hat Enterprise Linux 8"
      sudo kcli download image rhel8
      echo "Downloading Red Hat Enterprise Linux 9"
      sudo kcli download image rhel9
    fi

}

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
    
    if [ "A${RUN_ON_RHPDS}" == "Ayes" ];
    then
      KCLI_PROFILE=kcli-profiles-rhpds.yml
    else
      KCLI_PROFILE=kcli-profiles.yml
    fi
    
    if [ -f ${project_dir}/playbooks/vars/${KCLI_PROFILE} ];
    then
      cp "${project_dir}/playbooks/vars/${KCLI_PROFILE}" $HOME/qubinode-installer
    else 
      cp "${project_dir}/samples/${KCLI_PROFILE}" $HOME/qubinode-installer
    fi
    
    decrypt_ansible_vault "${vault_vars_file}" > /dev/null
    admin_username=$(awk '/admin_user:/ {print $2}' "${vars_file}")
    admin_password=$(awk '/admin_user_password:/ {print $2}' "${vault_vars_file}")
    encrypt_ansible_vault "${vaultfile}" >/dev/null
    sed -i "s/CHANGEUSER/${admin_username}/g" "${project_dir}/${KCLI_PROFILE}"
    sed -i "s/CHANGEPASSWORD/${admin_password}/g" "${project_dir}/${KCLI_PROFILE}"
    sudo mkdir -p /root/.kcli
    sudo cp "${project_dir}/${KCLI_PROFILE}" /root/.kcli/profiles.yml
    sudo mkdir -p ${HOME}/.kcli
    sudo cp "${project_dir}/${KCLI_PROFILE}" ${HOME}/.kcli/profiles.yml
    sudo rm -rf "${project_dir}/${KCLI_PROFILE}"
}

function create_static_profile_ip() {
    kvm_host_gw=$(awk '/kvm_host_gw:/ {print $2}' "${kvm_host_vars_file}")
    kvm_host_netmask=$(awk '/kvm_host_netmask:/ {print $2}' "${kvm_host_vars_file}")
    vm_libvirt_net=$(awk '/vm_libvirt_net:/ {print $2}' "${kvm_host_vars_file}")
    decrypt_ansible_vault "${vault_vars_file}" > /dev/null
    admin_username=$(awk '/admin_user:/ {print $2}' "${vars_file}")
    admin_password=$(awk '/admin_user_password:/ {print $2}' "${vault_vars_file}")
    encrypt_ansible_vault "${vaultfile}" >/dev/null


rhel8_static:
 image: rhel-8.6-x86_64-kvm.qcow2
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
        update_default_settings
        kcli_configure_images
    else 
      echo "kcli is installed"
      kcli --help
    fi 
}
