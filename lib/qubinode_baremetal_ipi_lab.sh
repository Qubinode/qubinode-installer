#!/bin/bash

setup_variables
product_in_use=baremetal_ipi_lab
source "${project_dir}/lib/qubinode_utils.sh"


function qubinode_ipi_lab_maintenance () {
    case ${product_maintenance} in
       configure_latest_ocp)
	        configure_latest_ocp
            ;;
       configure_disconnected_repo)
	        update_default_settings
            ;;
       install_packages)
	        install_packages
            ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}

function install_packages(){
  sudo dnf -y install podman httpd httpd-tools
}
function configure_disconnected_repo(){
  echo "Configure a Disconnected Registry and Red Hat Enterprise Linux CoreOS Cache"
  printf "%s\n" " ${red}Configure a Disconnected Registry and Red Hat Enterprise Linux CoreOS Cache${end}"
  printf "%s\n" "Link: https://github.com/RHFieldProductManagement/baremetal-ipi-lab/blob/master/03-configure-local-registry-cache.md"
}

function configure_latest_ocp(){
  echo "Configure Latest OCP"
  printf "%s\n" " ${red}Configure Latest OCP${end}"
  sudo rm -rf /usr/local/bin/oc
  curl -OL https://raw.githubusercontent.com/tosin2013/openshift-4-deployment-notes/master/pre-steps/configure-openshift-packages.sh
  chmod +x configure-openshift-packages.sh
  sudo ./configure-openshift-packages.sh -i
  sudo ln /usr/bin/oc /usr/local/bin/oc
  cd /home/lab-user/scripts
  export extract_dir=$(pwd)
  export VERSION=$(oc version  | grep Client | awk '{print $3}')
  echo $VERSION
  oc adm release extract --registry-config "$HOME/pull-secret.json" --command=openshift-baremetal-install --to "${extract_dir}" ${VERSION}
  sudo cp openshift-baremetal-install /usr/local/bin
}

function qubinode_setup_ipilab() {
  printf "%s\n" "   ${blu}Configuring ipilab${end}"
  printf "%s\n" "   ${blu}Link: https://github.com/RHFieldProductManagement/baremetal-ipi-lab${end}"
}
