#!/bin/bash


function qubinode_deploy_satellite () {
   qubinode_vm_deployment_precheck
   ACTIVE="${project_dir}/playbooks/vars/satellite_server.yml"
   SAMPLE="${project_dir}/samples/satellite_server.yml"
   test -f "${ACTIVE}" || cp "${SAMPLE}" "${ACTIVE}"
   SAT_PLAY="${project_dir}/playbooks/satellite_server.yml"

   if [ "A${teardown}" == "Atrue" ]
   then
       echo "Remove DNS VM"
       ansible-playbook "${SAT_PLAY}" --extra-vars "vm_teardown=true" || exit $?
   else
       echo "Deploy DNS VM"
       ansible-playbook "${SAT_PLAY}" || exit $?
   fi
}