#!/bin/bash

setup_variables
product_in_use=kcli
source "${project_dir}/lib/qubinode_utils.sh"
defaults_file="/usr/lib/python3.6/site-packages/kvirt/defaults.py"
kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
vars_file="${project_dir}/playbooks/vars/all.yml"
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
       *)
           echo "No arguement was passed"
           ;;
    esac
}

function kcli_configure_images(){
    echo "Configuring images"
    echo "Downloading Fedora"
    sudo kcli download image fedora34
    echo "Downloading Centos Streams"
    sudo kcli download image centos8stream
    echo "Downloading Red Hat Enterprise Linux 8"
    sudo kcli download image rhel8
    echo "Downloading Red Hat Enterprise Linux 7"
    sudo kcli download image rhel7
}

function update_default_settings(){
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

    cp "${project_dir}/samples/kcli-profiles.yml" $HOME/qubinode-installer
    decrypt_ansible_vault "${vault_vars_file}" > /dev/null
    admin_username=$(awk '/admin_user:/ {print $2}' "${vars_file}")
    admin_password=$(awk '/admin_user_password:/ {print $2}' "${vault_vars_file}")
    encrypt_ansible_vault "${vaultfile}" >/dev/null
    sed -i "s/CHANGEUSER/${admin_username}/g" "${project_dir}/kcli-profiles.yml"
    sed -i "s/CHANGEPASSWORD/${admin_password}/g" "${project_dir}/kcli-profiles.yml"
    sudo mkdir -p /root/.kcli
    sudo mv "${project_dir}/kcli-profiles.yml" /root/.kcli/profiles.yml
}

function qubinode_setup_kcli () {
    if [[ ! -f /usr/bin/kcli ]];
    then 
        sudo usermod -aG qemu,libvirt $USER
        curl https://raw.githubusercontent.com/karmab/kcli/master/install.sh | bash
        echo "eval '$(register-python-argcomplete kcli)'" >> ~/.bashrc
        update_default_settings
        kcli_configure_images
    else 
      echo "kcli is installed"
      kcli --help
    fi 
}