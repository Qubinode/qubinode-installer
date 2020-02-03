#!/bin/bash


function qubinode_autoinstall_openshift () {
    product_in_use="ocp3" # Tell the installer this is openshift3 installation
    openshift_product="${product_in_use}"
    qubinode_product_opt="${product_in_use}"
    openshift_auto_install=true # Tells the installer to use defaults options
    update_variable=true

    # load required files from samples to playbooks/vars/
    qubinode_required_prereqs

    # Check if the OpenShift cluster is already deployed
    printf "%s\n\n" ""
    #printf "%s\n" "  Checking if the OpenShift 3 Cluster is already deployed.."
    ping_openshift3_nodes
    check_webconsole_status
    if [[ "A${IS_OPENSHIFT3_NODES}" == "Ayes" ]] && [[ $WEBCONSOLE_STATUS -eq 200 ]]
    then
        printf "%s\n\n" " ${grn}OpenShift Cluster is already deployed${end}"
        openshift3_installation_msg
        exit 0
    fi

    if [[ "A${IS_OPENSHIFT3_NODES}" == "Ayes" ]] && [[ $WEBCONSOLE_STATUS -ne 200 ]]
    then
        tput cup $(stty size|awk '{print int($1/2);}') 0 && tput ed
        printf "%s" "  ${cyn}$OCP3_NODES_STATUS_MSG${end}"
        cat $VM_REPORT
        printf "%s\n\n" ""
    fi

    printf "\n\n ${yel}*************************${end}\n"
    printf " ${yel}*${end} ${cyn}Deploying OpenShift 3${end}${yel} *${end}\n"
    printf " ${yel}*************************${end}\n\n"
    
    # Add current user to sudoers, setup global variables, run additional
    # prereqs, setup current user ssh key, ask user if they want to
    # deploy a qubinode system.
    qubinode_installer_setup
    
    # Ensure host system is setup as a KVM host
    qubinode_setup_kvm_host
    printf "\n\n****************************\n"
    printf     "* Deploy IdM DNS Server    *\n"
    printf     "****************************\n"
    qubinode_deploy_idm
    
    sed -i "s/openshift_product:.*/openshift_product: $openshift_product/g" "${ocp3_vars_file}"
    sed -i "s/openshift_auto_install:.*/openshift_auto_install: "$openshift_auto_install"/g" "${ocp3_vars_file}"
    openshift_enterprise_deployment
}
