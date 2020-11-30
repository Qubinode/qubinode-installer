#!/bin/bash

function qubinode_product_deployment () {
    # this function deploys a supported product
    PRODUCT_OPTION=$1

    # the product_opt is still use by some functions and it should be refactored
    product_opt="${PRODUCT_OPTION}"
    AVAIL_PRODUCTS="okd4 ocp4 satellite idm kvmhost tower"
    case $PRODUCT_OPTION in
          okd4)
	      openshift4_variables
              if [ "A${teardown}" == "Atrue" ]
              then
                  openshift4_qubinode_teardown
              elif [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  openshift4_server_maintenance
              else
                  ASK_SIZE=true
                  qubinode_deploy_ocp4
              fi
              ;;
          ocp4)
              CHECK_PULL_SECRET=yes
	      openshift4_variables
              if [ "A${teardown}" == "Atrue" ]
              then
                  openshift4_qubinode_teardown
              elif [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  openshift4_server_maintenance
              else
                  ASK_SIZE=true
                  CHECK_PULL_SECRET=no
                  setup_download_options 
                  qubinode_deploy_ocp4
              fi
              ;;
          satellite)
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_teardown_satellite
              else
                  rhel_major=7
                  CHECK_PULL_SECRET=no
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
                  CHECK_PULL_SECRET=no
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
                  CHECK_PULL_SECRET=no
                  echo "Running IdM VM deploy function"
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
                      CHECK_PULL_SECRET=no
                      #setup_download_options
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
        # This ensures the system is base requires are met
        # before -m ansible -m rhsm -m host can be executed
        qubinode_base_requirements
    elif [ "${qubinode_maintenance_opt}" == "rhsm" ]
    then
        qubinode_rhsm_register
    elif [ "${qubinode_maintenance_opt}" == "ansible" ]
    then
        qubinode_setup_ansible
    elif [ "${qubinode_maintenance_opt}" == "host" ] || [ "${maintenance}" == "kvmhost" ]
    then
	## this should be replace as qubinode_setup does everthing that's required
        #qubinode_setup_kvm_host
	qubinode_setup
    elif [ "${qubinode_maintenance_opt}" == "rebuild_qubinode" ]
    then
        rebuild_qubinode
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
