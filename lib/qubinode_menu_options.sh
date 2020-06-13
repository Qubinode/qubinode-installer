#!/bin/bash

function qubinode_product_deployment () {
    # this function deploys a supported product
    PRODUCT_OPTION=$1

    # the product_opt is still use by some functions and it should be refactored
    product_opt="${PRODUCT_OPTION}"
    AVAIL_PRODUCTS="okd3 ocp3 ocp4 satellite idm kvmhost tower"
    case $PRODUCT_OPTION in
          ocp3)
              openshift3_variables
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_teardown_openshift
              elif [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  openshift3_server_maintenance
              else
                  setup_download_options
                  openshift_enterprise_deployment
              fi
              ;;
          okd3)
              openshift3_variables
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_teardown_openshift
              elif [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  openshift3_server_maintenance
              else
                  okd3_deployment
              fi
              ;;
          ocp4)
              if [ "A${teardown}" == "Atrue" ]
              then
                  openshift4_qubinode_teardown
              elif [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  openshift4_server_maintenance
              else
                  ASK_SIZE=true
                  rhel_major=$(awk '/^qcow_rhel_release:/ {print $2}' "${project_dir}/playbooks/vars/idm.yml")
                  setup_download_options 
                  qubinode_deploy_ocp4
              fi
              ;;
          satellite)
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_teardown_satellite
              else
                  echo "Installing Satellite"
                  rhel_major=$(awk '/^qcow_rhel_release:/ {print $2}' "${project_dir}/playbooks/vars/satellite.yml")
                  setup_download_options
                  download_files
                  qubinode_deploy_satellite
              fi
              ;;
          tower)
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_teardown_tower
              else
                  setup_download_options
                  download_files
                  qubinode_deploy_tower
              fi
              ;;
          idm)
              if [ "A${teardown}" == "Atrue" ]
              then
                  echo "Running IdM VM teardown function"
                  qubinode_teardown_idm
              elif [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  qubinode_idm_maintenance
              else
                  echo "Running IdM VM deploy function"
                  rhel_major=$(awk '/^qcow_rhel_release:/ {print $2}' "${project_dir}/playbooks/vars/idm.yml")
                  setup_download_options
                  download_files
                  qubinode_deploy_idm
              fi
              ;;
          rhel)
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_rhel_teardown
              else
                  if [ "A${qubinode_maintenance}" == "Atrue" ]
                  then
                      qubinode_rhel_maintenance
                  else
                      setup_download_options
                      download_files
                      qubinode_deploy_rhel
                  fi
              fi
              ;;
          kvmhost)
              echo "Setting up KVM host"
              qubinode_setup_kvm_host
              ;;
          *)
              echo "Product ${PRODUCT_OPTION} is not supported."
              echo "Supported products are: ${AVAIL_PRODUCTS}"
              exit 1
              ;;
    esac

}

function qubinode_maintenance_options () {
    if [ "${qubinode_maintenance_opt}" == "clean" ]
    then
        qubinode_project_cleanup
    elif [ "${qubinode_maintenance_opt}" == "hwp" ]
    then
        # Collect hardware information
        create_qubinode_profile_log
    elif [ "${qubinode_maintenance_opt}" == "setup" ]
    then
        qubinode_installer_setup
    elif [ "${qubinode_maintenance_opt}" == "rhsm" ]
    then
        qubinode_rhsm_register
    elif [ "${qubinode_maintenance_opt}" == "ansible" ]
    then
        qubinode_setup_ansible
    elif [ "${qubinode_maintenance_opt}" == "host" ] || [ "${maintenance}" == "kvmhost" ]
    then
        qubinode_setup_kvm_host
    elif [ "${qubinode_maintenance_opt}" == "deploy_nodes" ]
    then
        deploy_openshift3_nodes
    elif [ "${qubinode_maintenance_opt}" == "undeploy" ]
    then
        #TODO: this should remove all VMs and clean up the project folder
        qubinode_vm_manager undeploy
    elif [ "${qubinode_maintenance_opt}" == "uninstall_openshift" ]
    then
      #TODO: this should remove all VMs and clean up the project folder
        qubinode_uninstall_openshift
    else
        display_help
    fi
}
