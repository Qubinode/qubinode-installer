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
                  openshift_enterprise_deployment
              fi
              ;;
          ocp4)
              openshift4_variables
              if [ "A${teardown}" == "Atrue" ]
              then
                  openshift4_qubinode_teardown
              elif [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  openshift4_server_maintenance
              else
                  openshift4_enterprise_deployment
              fi
              ;;
          satellite)
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_teardown_satellite
              else
                  echo "Installing Satellite"
                  qubinode_deploy_satellite
              fi
              ;;
          tower)
              if [ "A${teardown}" == "Atrue" ]
              then
                  qubinode_teardown_tower
              else
                  qubinode_deploy_tower
              fi
              ;;
          idm)
              if [ "A${teardown}" == "Atrue" ]
              then
                  echo "Running IdM VM teardown function"
                  qubinode_teardown_idm
              else
                  echo "Running IdM VM deploy function"
                  qubinode_deploy_idm
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

