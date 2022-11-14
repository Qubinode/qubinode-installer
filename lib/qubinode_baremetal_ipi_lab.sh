#!/bin/bash

setup_variables
product_in_use=baremetal_ipi_lab
source "${project_dir}/lib/qubinode_utils.sh"

function step03(){
  echo "Configure a Disconnected Registry and Red Hat Enterprise Linux CoreOS Cache"
  printf "%s\n" " ${red}Configure a Disconnected Registry and Red Hat Enterprise Linux CoreOS Cache${end}"
  printf "%s\n" "Link: https://github.com/RHFieldProductManagement/baremetal-ipi-lab/blob/master/03-configure-local-registry-cache.md"
}

function qubinode_setup_ipilab() {
  printf "%s\n" "   ${blu}Configuring ipilab${end}"
  printf "%s\n" "   ${blu}Link: https://github.com/RHFieldProductManagement/baremetal-ipi-lab${end}"
}
