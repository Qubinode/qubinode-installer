  #!/bin/bash

  setup_variables
  IDM_VM_PLAY="${project_dir}/playbooks/idm_vm_deployment.yml"
  product_in_use=idm
  idm_vars_file="${project_dir}/playbooks/vars/idm.yml"
  # Check if we should setup qubinode
  DNS_SERVER_NAME=$(awk -F'-' '/idm_hostname:/ {print $2; exit}' "${idm_vars_file}" | tr -d '"')
  prefix=$(awk '/instance_prefix/ {print $2;exit}' "${vars_file}")
  suffix=$(awk -F '-' '/idm_hostname:/ {print $2;exit}' "${idm_vars_file}" |tr -d '"')
  idm_srv_hostname="$prefix-$suffix"
  idm_srv_fqdn="$prefix-$suffix.$domain"

  function display_idmsrv_unavailable () {
          printf "%s\n" "${yel}Either the IdM server variable idm_public_ip is not set.${end}"
          printf "%s\n" "${yel}Or the IdM server is not reachable.${end}"
          printf "%s\n" "${yel}Ensure the IdM server is running, update the variable and try again.${end}"
          exit 1
  }

  function ask_user_for_idm_password () {
      # decrypt ansible vault file
      decrypt_ansible_vault "${vaultfile}"

      # This is the password used to log into the IDM server webconsole and also the admin user
      if grep '""' "${vaultfile}"|grep -q idm_admin_pwd
      then
          unset idm_admin_pwd
          while [[ ${#idm_admin_pwd} -lt 8 ]]
          do
             echo -n " Enter a password for the IDM server console and press ${grn}[ENTER]${end}: "
             read_sensitive_data
             idm_admin_pwd="${sensitive_data}"
             if [ ${#idm_admin_pwd} -lt 8 ]
             then
                 printf "%s\n" "    ${yel}**IMPORTANT**${end}"
                 printf "%s\n" " The password must be at least ${yel}8${end} characters long."
                 printf "%s\n" " Please re-run the installer"
             fi
          done
          sed -i "s/idm_admin_pwd: \"\"/idm_admin_pwd: "$idm_admin_pwd"/g" "${vaultfile}"
          echo ""
          #fi
      fi

      # encrypt ansible vault
      encrypt_ansible_vault "${vaultfile}"

      # Generate a ramdom password for IDM directory manager
      # This will not prompt the user
      if grep '""' "${vaultfile}"|grep -q idm_dm_pwd
      then
          idm_dm_pwd=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
          sed -i "s/idm_dm_pwd: \"\"/idm_dm_pwd: "$idm_dm_pwd"/g" "${vaultfile}"
      fi
  }

  function ask_user_for_custom_idm_server () {
      # Ask if this host should be setup as a qubinode host
      if [ "A${DNS_SERVER_NAME}" == "Anone" ]
      then
          printf "%s\n" "    ${cyn}Red Hat Identity Management (IdM)${end}"
          printf "%s\n\n" "    ${cyn}*********************************${end}"
          printf "%s\n" " The Qubinode depends on IdM as the DNS server."
          printf "%s\n" " To provide DNS resolutions for the services deployed."
          printf "%s\n" " The installer default action is deploy a local IdM server."
          printf "%s\n\n" " You can also choose to use an existing IdM server."

          confirm " ${blu}Would you like to use an existing IdM server?${end} ${yel}yes/no${end}"
          if [ "A${response}" == "Ayes" ]
          then
              static_ip_msg="Enter the ip address for the existing IdM server"
              static_ip_result_msg="The qubinode-installer will connect to the IdM server on"
              set_idm_static_ip

              printf "%s\n\n" ""
              read -p " ${yel}What is the FQDN of the existing IdM server?${end} " IDM_NAME
              idm_hostname="${IDM_NAME}"
              confirm " ${blu}You entered${end} ${yel}$idm_hostname${end}${blu}, is this correct?${end} ${yel}yes/no${end}"
              if [ "A${response}" == "Ayes" ]
              then
                  sed -i "s/idm_hostname:.*/idm_hostname: "$idm_hostname"/g" "${idm_vars_file}"
                  sed -i "s/ipa_host:.*/ipa_host: "$idm_hostname"/g" "${idm_vars_file}"
                  printf "%s\n" ""
                  printf "%s\n" " ${blu}Your IdM server hostname is set to${end} ${yel}$idm_hostname${end}"
              fi

              printf "%s\n\n" ""
              read -p " What is the username for the existing IdM server admin user? " $IDM_USER
              idm_admin_user=$IDM_USER
              confirm " ${blu}You entered${end} ${yel}$idm_admin_user${end}${blu}, is this correct?${end} ${yel}yes/no${end}"
              if [ "A${response}" == "Ayes" ]
              then
                  sed -i "s/idm_admin_user:.*/idm_admin_user: "$idm_admin_user"/g" "${idm_vars_file}"
                  printf "%s\n" ""
              fi


              # Tell installer not to deploy IdM server
              sed -i "s/deploy_idm_server:.*/deploy_idm_server: no/g" "${idm_vars_file}"
          else
              # Tell installer to deploy IdM server
              sed -i "s/deploy_idm_server:.*/deploy_idm_server: yes/g" "${idm_vars_file}"

              # Setting default IdM server name
              sed -i 's/idm_hostname:.*/idm_hostname: "{{ instance_prefix }}-dns01"/g' "${idm_vars_file}"

              printf "%s\n" " The IdM server will be assigned a dynamic ip address from"
              printf "%s\n\n" " your network. You can assign a static ip address instead."
              confirm " ${blu}Would you like to assign a static ip address to the IdM server?${end} ${yel}yes/no${end}"
              if [ "A${response}" == "Ayes" ]
              then
                  static_ip_msg="Enter the ip address you would like to assign to the IdM server"
                  static_ip_result_msg="The qubinode-installer will connect to the IdM server on"
                  set_idm_static_ip
              fi
          fi
      fi
  }

  function set_idm_static_ip () {
      printf "%s\n" ""
      read -p " ${yel}$static_ip_msg:${end} " USER_IDM_SERVER_IP
      idm_server_ip="${USER_IDM_SERVER_IP}"
      confirm " ${blu}You entered${end} ${yel}$idm_server_ip${end}${blu}, is this correct?${end} ${yel}yes/no${end}"
      if [ "A${response}" == "Ayes" ]
      then
          sed -i "s/idm_server_ip:.*/idm_server_ip: "$USER_IDM_SERVER_IP"/g" "${idm_vars_file}"
          printf "%s\n" " ${blu}$static_ip_result_msg${end} ${yel}$idm_server_ip${end}"
      fi
  }

  function qubinode_idm_ask_ip_address () {
      IDM_STATIC=$(awk '/idm_check_static_ip/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')
      CURRENT_IDM_IP=$(awk '/idm_server_ip:/ {print $2}' "${idm_vars_file}")
      echo "${IDM_STATIC}" | grep -qE 'yes|no'
      RESULT=$?
      if [ "A${RESULT}" == "A1" ]
      then
          echo "Would you like to set a static IP for for the IdM server?"
          echo "Default choice is to choose: No"
          confirm " Yes/No"
          if [ "A${response}" == "Ayes" ]
          then
              sed -i "s/idm_check_static_ip:.*/idm_check_static_ip: yes/g" ${idm_vars_file}
          else
              sed -i "s/idm_check_static_ip:.*/idm_check_static_ip: no/g" ${idm_vars_file}
          fi
      fi

      # Check on vailable IP
      IDM_STATIC=$(awk '/idm_check_static_ip/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')
      MSGUK="The varaible idm_server_ip in $idm_vars_file is set to an unknown value of $CURRENT_IDM_IP"

     if ! curl -k -s "https://${idm_srv_fqdn}/ipa/config/ca.crt" > /dev/null
     then
         if [ "A${IDM_STATIC}" == "Ayes" ]
         then
             if [ "A${CURRENT_IDM_IP}" == 'A""' ]
             then
                 set_idm_static_ip
             elif [ "A${CURRENT_IDM_IP}" != 'A""' ]
             then
                 echo "IdM server ip address is set to ${CURRENT_IDM_IP}"
                 confirm "Do you want to change? yes/no"
                 if [ "A${response}" == "Ayes" ]
                 then
                     set_idm_static_ip
                 fi
             else
                 echo "${MSGUK}"
                 echo 'Please reset to "" and try again'
                 exit 1
             fi
         fi
     fi
  }



  function isIdMrunning () {
     if ! curl -k -s "https://${idm_srv_fqdn}/ipa/config/ca.crt" > /dev/null
     then
         idm_running=false
     elif curl -k -s "https://${idm_srv_fqdn}/ipa/config/ca.crt" > /dev/null
     then
         idm_running=true
     else
         idm_running=false
     fi
     return ${idm_running}
  }

  function qubinode_teardown_idm () {
      IDM_PLAY_CLEANUP="${project_dir}/playbooks/idm_server_cleanup.yml"
      if sudo virsh list --all |grep -q "${idm_srv_hostname}"
      then
          echo "Remove IdM VM"
          ansible-playbook "${IDM_VM_PLAY}" --extra-vars "vm_teardown=true" || exit $?
      fi
      echo "Ensure IdM server deployment is cleaned up"
      ansible-playbook "${IDM_PLAY_CLEANUP}" || exit $?

      printf "\n\n*************************\n"
      printf "* IdM server VM deleted *\n"
      printf "*************************\n\n"
  }

  function qubinode_deploy_idm_vm () {
     if grep deploy_idm_server "${idm_vars_file}" | grep -q yes
     then
         qubinode_vm_deployment_precheck
         isIdMrunning

         IDM_PLAY_CLEANUP="${project_dir}/playbooks/idm_server_cleanup.yml"
         SET_IDM_STATIC_IP=$(awk '/idm_check_static_ip/ {print $2; exit}' "${idm_vars_file}"| tr -d '"')

         if [ "A${idm_running}" == "Afalse" ]
         then
             echo "running playbook ${IDM_VM_PLAY}"
             if [ "A${SET_IDM_STATIC_IP}" == "Ayes" ]
             then
                 echo "Deploy with custom IP"
                 idm_server_ip=$(awk '/idm_server_ip:/ {print $2}' "${idm_vars_file}")
                 ansible-playbook "${IDM_VM_PLAY}" --extra-vars "vm_ipaddress=${idm_server_ip}"|| exit $?
              else
                  echo "Deploy without custom IP"
                  ansible-playbook "${IDM_VM_PLAY}" || exit $?
              fi
          fi
      fi
  }

  function qubinode_install_idm () {
     qubinode_vm_deployment_precheck
     ask_user_input
     IDM_INSTALL_PLAY="${project_dir}/playbooks/idm_server.yml"

     echo "Install and configure the IdM server"
     idm_server_ip=$(awk '/idm_server_ip:/ {print $2}' "${idm_vars_file}")
     echo "Current IP of IDM Server ${idm_server_ip}" || exit $?
     ansible-playbook "${IDM_INSTALL_PLAY}" --extra-vars "vm_ipaddress=${idm_server_ip}" || exit $?
     isIdMrunning
     if [ "A${idm_running}" == "Atrue" ]
     then
       printf "\n\n*********************************************************************************\n"
       printf "    **IdM server is installed**\n"
       printf "         Url: https://${idm_srv_fqdn}/ipa \n"
       printf "         Username: $(whoami) \n"
       printf "         Password: the vault variable *admin_user_password* \n\n"
       printf "Run: ansible-vault edit ${project_dir}/playbooks/vars/vault.yml \n"
       printf "*******************************************************************************\n\n"
     else
       echo "IDM Server was not properly deployed please verify deployment."
       exit 1
     fi
  }

  function qubinode_deploy_idm () {
      qubinode_deploy_idm_vm
      qubinode_install_idm
  }
