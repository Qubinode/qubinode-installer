#!/bin/bash

setup_variables
product_in_use=baremetal_ipi_lab
source "${project_dir}/lib/qubinode_utils.sh"


  RHEL_VERSION=$(get_rhel_version)
  if [[ $RHEL_VERSION == "FEDORA" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.10)/site-packages/kvirt/defaults.py"
  elif [[ $RHEL_VERSION == "RHEL8" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.6)/site-packages/kvirt/defaults.py"
  elif [[ $RHEL_VERSION == "ROCKY8" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.6)/site-packages/kvirt/defaults.py"

  elif [[ $(get_distro) == "centos" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.9)/site-packages/kvirt/defaults.py"
  else 
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.9)/site-packages/kvirt/defaults.py"
  fi 


function step03(){
  echo "Configure a Disconnected Registry and Red Hat Enterprise Linux CoreOS Cache"
  printf "%s\n" " ${red}Configure a Disconnected Registry and Red Hat Enterprise Linux CoreOS Cache${end}"
  printf "%s\n" "Link: https://github.com/RHFieldProductManagement/baremetal-ipi-lab/blob/master/03-configure-local-registry-cache.md"
}

function qubinode_setup_ipi_lab() {
  echo "Configuring ipi lab"
}
