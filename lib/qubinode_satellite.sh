#!/bin/bash


function qubinode_deploy_satellite () {
   qubinode_vm_deployment_precheck
   ask_user_input
   ACTIVE_VARS_FILE="${project_dir}/playbooks/vars/satellite_server.yml"
   SAMPLE_VARS_FILE="${project_dir}/samples/satellite_server.yml"
   test -f "${ACTIVE_VARS_FILE}" || cp "${SAMPLE_VARS_FILE}" "${ACTIVE_VARS_FILE}"
   SATELLITE_PLAY="${project_dir}/playbooks/deploy_satellite.yml"
   SATELLITE_SERVER_IP=$(awk '/qbn-sat/ {print $2}' "${project_dir}/inventory/hosts" |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
   ADMIN_USER=$(awk '/^admin_user:/ {print $2;exit}' "${vars_file}")
   SATELLITE_SERVER_DNS=$(dig +short -x "${SATELLITE_SERVER_IP}")

   # Check for ansible and role swygue-install-satellite
   if [ -f /usr/bin/ansible ]
   then
       ROLE_PRESENT=$(ansible-galaxy list | grep 'swygue-install-satellite')
       if [ "A${ROLE_PRESENT}" == "A" ]
       then
           qubinode_setup_ansible
       fi
   else
       qubinode_setup_ansible
   fi


   # Deploy or teardown Satellite
   if [ "A${teardown}" == "Atrue" ]
   then
       if [ "A${SATELLITE_SERVER_DNS}" != "A" ]
       then
          echo "Removing Satelite DNS records"
          ansible-playbook "${SATELLITE_PLAY}" --extra-vars "vm_teardown=true" -t create_dns_records || exit $?
       fi

       if sudo virsh list | grep -q qbn-sat01
       then
           echo "Removing Satellite VM"
           ansible-playbook "${SATELLITE_PLAY}" --extra-vars "vm_teardown=true" --skip-tags create_dns_records || exit $?
       fi
   else
       if [ "A${SATELLITE_SERVER_IP}" != "A" ]
       then
           if ! ssh -o StrictHostKeyChecking=no "${ADMIN_USER}@${SATELLITE_SERVER_IP}" 'exit'
           then
               echo "Deploy Satellite VM and create DNS records"
               ansible-playbook "${SATELLITE_PLAY}" || exit $?
           elif [ "A${SATELLITE_SERVER_DNS}" == "A" ]
           then
               echo "Create Satellite server DNS records"
               qubinode_deploy_idm
               ansible-playbook "${SATELLITE_PLAY}" -t create_dns_records || exit $?
           else
               echo "The Satellite server VM appears to be deployed and in good state."
           fi
       else
           echo "Deploy Satellite VM and create DNS records"
           qubinode_deploy_idm
           ansible-playbook "${SATELLITE_PLAY}" || exit $?
       fi
   fi
}
