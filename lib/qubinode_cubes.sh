


function qubinode_vm_manager () {
   # Deploy VMS
   prereqs
   deploy_vm_opt="$1"

   if [ "A${teardown}" != "Atrue" ]
   then
       # Ensure the setup function as was executed
       if [ ! -f "${vars_file}" ]
       then
           echo "${vars_file} is missing"
           echo "Please run qubinode-installer -m setup"
           echo ""
           exit 1
       fi
    
       # Ensure the ansible function has bee executed
       ROLE_PRESENT=$(ansible-galaxy list | grep 'ansible-role-rhel7-kvm-cloud-init')
       if [ ! -f /usr/bin/ansible ]
       then
           echo "Ansible is not installed"
           echo "Please run qubinode-installer -m ansible"
           echo ""
           exit 1
       elif [ "A${ROLE_PRESENT}" == "A" ]
       then
           echo "Required role ansible-role-rhel7-kvm-cloud-init is missing."
           echo "Please run run qubinode-installer -m ansible"
           echo ""
           exit 1
       fi
    
       # Check for required Qcow image
       check_for_rhel_qcow_image
    fi

   if [ "A${deploy_vm_opt}" == "Adeploy_dns" ]
   then
       if [ "A${teardown}" == "Atrue" ]
       then
           echo "Remove DNS VM"
           ansible-playbook "${DNS_PLAY}" --extra-vars "vm_teardown=true" || exit $?
       else
           echo "Deploy DNS VM"
           ansible-playbook "${DNS_PLAY}" || exit $?
       fi
   elif [ "A${deploy_vm_opt}" == "Adeploy_nodes" ]
   then
       if [ "A${teardown}" == "Atrue" ]
       then
           echo "Remove ${product} VMs"
           ansible-playbook "${NODES_DNS_RECORDS}" --extra-vars "vm_teardown=true" || exit $?
           ansible-playbook "${NODES_PLAY}" --extra-vars "vm_teardown=true" || exit $?
           if [[ -f ${CHECK_OCP_INVENTORY}  ]]; then
              rm -rf ${CHECK_OCP_INVENTORY}
           fi
       else
           echo "Deploy ${product} VMs"
           ansible-playbook "${NODES_PLAY}" || exit $?
           ansible-playbook "${NODES_POST_PLAY}" || exit $?
       fi
   elif [ "A${deploy_vm_opt}" == "Askip" ]
   then
       echo "Skipping running ${project_dir}/playbooks/deploy_vms.yml" || exit $?
   else
        display_help
   fi
}
