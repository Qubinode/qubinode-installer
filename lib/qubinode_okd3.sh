#!/bin/bash
function setup_required_paths () {
    current_dir="`dirname \"$0\"`"
    project_dir="$(dirname ${current_dir})"
    project_dir="`( cd \"$project_dir\" && pwd )`"
    if [ -z "$project_dir" ] ; then
        config_err_msg; exit 1
    fi

    if [ ! -d "${project_dir}/playbooks/vars" ] ; then
        config_err_msg; exit 1
    fi
}

function qubinode_autoinstall_okd3() {
    product_in_use="okd3" # Tell the installer this is openshift3 installation
    openshift_product="${product_in_use}"
    qubinode_product_opt="${product_in_use}"
    openshift_auto_install=true # Tells the installer to use defaults options
    update_variable=true

    setup_required_paths
    playbooks_dir="${project_dir}/playbooks"
    source "${project_dir}/lib/qubinode_openshift3_utils.sh"

    # Load all global openshift variable
    set_openshift_production_variables

    # load required files from samples to playbooks/vars/
    qubinode_required_prereqs

    # Add current user to sudoers, setup global variables, run additional
    # prereqs, setup current user ssh key, ask user if they want to
    # deploy a qubinode system.
    qubinode_installer_setup

    # Check if the OpenShift cluster is already deployed
    printf "%s\n\n" ""
    #printf "%s\n" "  Checking if the OpenShift 3 Cluster is already deployed.."
    ping_openshift3_nodes
    check_webconsole_status_ocp3
    if [[ "A${IS_OPENSHIFT3_NODES}" == "Ayes" ]] &&  [ $WEBCONSOLE_STATUS -eq 200 ]
    then
        printf "%s\n\n" " ${grn}OpenShift Cluster is already deployed${end}"
        openshift3_installation_msg
        exit 0
    fi

    if [[ "A${IS_OPENSHIFT3_NODES}" == "Ayes" ]] && [ $WEBCONSOLE_STATUS -eq 200 ]
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
    openshift4_kvm_health_check
    if [[ "A${KVM_IN_GOOD_HEALTH}" == "Ano"  ]]; then
      qubinode_setup_kvm_host
    fi

    # Deploy IdM Server
    openshift4_idm_health_check
    if [[  "A${IDM_IN_GOOD_HEALTH}" == "Ano"  ]]; then
      qubinode_deploy_idm
    fi

    sed -i "s/openshift_product:.*/openshift_product: $openshift_product/g" "${playbooks_dir}/vars/okd3.yml"
    sed -i "s/openshift_auto_install:.*/openshift_auto_install: "$openshift_auto_install"/g" "${playbooks_dir}/vars/okd3.yml"
    okd3_deployment
}
