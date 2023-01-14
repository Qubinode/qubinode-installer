#!/bin/bash

###
## This function is used to deploy a product.
###
function qubinode_product_deployment () {
    # this function deploys a supported product
    PRODUCT_OPTION=$1

    # the product_opt is still use by some functions and it should be refactored
    product_opt="${PRODUCT_OPTION}"
    AVAIL_PRODUCTS="okd4 ocp4 ai_svc_universal satellite idm kvmhost tower kcli gozones ipilab kvm_install_vm vyos_router deploy_vyos_router sushy_tools"
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
		  printf "%s\n" "   ${blu}Running IdM VM teardown function${end}"
                  qubinode_teardown_idm
              elif [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  qubinode_idm_maintenance
              else
                  CHECK_PULL_SECRET=no
		  printf "%s\n" "   ${blu}Running IdM VM deploy function${end}"
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
	      printf "%s\n" "   ${blu}Setting up KVM host${end}"
              qubinode_setup_kvm_host
              ;;
          kcli)
              if [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  qubinode_kcli_maintenance
              else
		    printf "%s\n" "   ${blu}Configuring kcli${end}"
                    qubinode_setup_kcli
              fi
              ;;
          kvm_install_vm)
              if [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  qubinode_kvm_install_vm_maintenance
              else
		    printf "%s\n" "   ${blu}Configuring kvm_install_vm${end}"
                    qubinode_setup_kvm_install_vm
              fi
              ;;
          gozones)
              if [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  qubinode_gozones_maintenance
              else
		    printf "%s\n" "   ${blu}Configuring gozones dns${end}"
                    qubinode_setup_gozones
              fi
              ;;

          vyos_router)
              if [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  qubinode_vyos_router_maintenance
              else
		            printf "%s\n" "   ${blu}Please pass required command${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p vyos_router -m create${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p vyos_router -m destroy${end}"
              fi
              ;;

          deploy_vyos_router)
              if [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  qubinode_deploy_vyos_router_maintenance
              else
		            printf "%s\n" "   ${blu}Please pass required command${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p deploy_vyos_router -m create${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p deploy_vyos_router -m destroy${end}"
              fi
              ;;

            ai_svc_universal)
              if [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  ai_svc_universal_tools_maintenance
              else
		            printf "%s\n" "   ${blu}Please pass required command${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p ai_svc_universal -m create${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p ai_svc_universal -m destroy${end}"
              fi
              ;;

            sushy_tools)
              if [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  sushy_tools_maintenance
              else
		            printf "%s\n" "   ${blu}Please pass required command${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p sushy_tools -m create${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p sushy_tools -m destroy_sushy_tools${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p sushy_tools -m create_vms${end}"
                    printf "%s\n" "   ${blu}./qubinode-installer -p sushy_tools -m destroy_vms${end}"
              fi
              ;;

          ipilab)
              if [ "A${qubinode_maintenance}" == "Atrue" ]
              then
                  qubinode_ipi_lab_maintenance
              else
                  qubinode_setup_ipilab
              fi
              ;;
          *)
	      printf "%s\n" "   Product ${mag}${PRODUCT_OPTION}${end} is not supported"
	      printf "%s\n" "   Supported products are: ${mag}${AVAIL_PRODUCTS}${end}"
              exit 1
              ;;
    esac

}

###
## This function is used to perform maintenance on the qubinode.
###
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
