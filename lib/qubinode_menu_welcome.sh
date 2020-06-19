display_openshift_msg_ocp3 () {
    printf "%s\n" "  ${yel}****************************************************************************${end}"
    printf "%s\n\n" "        ${cyn}${txb}Red Hat Openshift Container Platform 3 (OCP3)${txend}${end}"
    printf "%s\n" "    Installing OCP3 requires a valid Red Hat subscription. If you do not have,"
    printf "%s\n" "    one exit the install and choose OKD3 from the menu option. The size of the"
    printf "%s\n" "    OCP3 cluster that gets deployed is based on your hardware profile."
    printf "%s\n\n" "    Hardware profiles are defined as:"
    display_hardware_profile_msg
    printf "%s\n\n" "  ${yel}****************************************************************************${end}"

    confirm "  Do you want to proceed? yes/no"
    if [ "A${response}" == "Ayes" ]
    then
        qubinode_autoinstall_openshift
    else
        display_other_options
    fi
}

display_openshift_msg_okd3 () {
    printf "%s\n" "  ${yel}****************************************************************************${end}"
    printf "%s\n\n" "        ${cyn}${txb}OKD: The Origin Community Distribution of Kubernetes (OKD)${txend}${end}"
    printf "%s\n" "    OKD is the Origin community distribution of Kubernetes optimized for "
    printf "%s\n" "    continuous application development and multi-tenant deployment."
    printf "%s\n\n" "    Hardware profiles are defined as:"
    display_hardware_profile_msg
    printf "%s\n\n" "  ${yel}****************************************************************************${end}"

    confirm "  Do you want to proceed? yes/no"
    if [ "A${response}" == "Ayes" ]
    then
        qubinode_autoinstall_okd3
    else
        display_other_options
    fi
}

display_hardware_profile_msg () {
    printf "%s\n" "      ${blu}Minimal     - 30G Memory and 370G Storage${end}"
    printf "%s\n" "      ${blu}Standard    - 80G Memory and 900G Storage${end}"
    printf "%s\n" "      ${blu}Performance - 88G Memory and 1340G Storage${end}"
    printf "%s\n" ""
}

display_openshift_msg_ocp4 () {
    printf "%s\n" "  ${yel}****************************************************************************${end}"
    printf "%s\n\n" "        ${cyn}${txb}Red Hat Openshift Container Platform 4 (OCP4)${txend}${end}"
    printf "%s\n" "    The default product option is to install OCP4. The deployment consists of"
    printf "%s\n" "    ${cyn}3 masters${end} and ${cyn}3 computes${end}. It requires a minimum of ${cyn}96 Gib${end} memory and${cyn} 8 cores${end}."
    printf "%s\n" "    Each node is deployed with ${cyn}16 Gib${end} memory and ${cyn}4 vCPUs${end} with NFS for persistent"
    printf "%s\n" "    storage. If you don't meet these requirements exit the install and run"
    printf "%s\n\n" "    ${cyn}./qubinode-installer -p ocp4${end} for options to deploy a smaller cluster."

    printf "%s\n" "    The installer also requires your OpenShift pull-secret. Please refer to"
    printf "%s\n\n" "    the documentation for info on obtaining your pull secret."
    #display_hardware_profile_msg
    printf "%s\n\n" "  ${yel}****************************************************************************${end}"

    default_message=("Continue with the default installation" "Display other options" "Exit")
    createmenu "${default_message[@]}"
    result=($(echo "${selected_option}"))
    if [ "A${result}" == "ADisplay" ]
    then
        display_other_options
    elif [ "A${result}" == "AContinue" ]
    then
        ASK_SIZE=false
        rhel_major=$(awk '/^qcow_rhel_release:/ {print $2}' "${project_dir}/playbooks/vars/idm.yml")
        setup_download_options
        qubinode_deploy_ocp4
    elif [ "A${result}" == "AExit" ]
    then
        exit 0
    else
        print "%s\n" " ${red}Unknown issue, please run the installer again${end}"
    fi
}


display_other_options () {
    printf "%s\n\n" ""
    #other_options=("${cyn}OCP4${end} - OpenShift 4" "${cyn}OKD3${end} - Origin Community Distribution" "${cyn}Tower${end} - Ansible Tower" "${cyn}Satellite${end} - Red Hat Satellite Server" "${cyn}IdM${end} - Red Hat Identity Management" "${cyn}Display the help menu${end}")

    other_options=("IdM - Red Hat Identity Management" "Display the help menu")
    #other_options=("Tower - Ansible Tower" "Satellite - Red Hat Satellite Server" "IdM - Red Hat Identity Management" "Display the help menu")

    createmenu "${other_options[@]}"
    result=($(echo "${selected_option}"))

    if [ "A${result}" == "ADisplay" ]
    then
        display_help
    elif [ "A${result}" == "AOCP3" ]
    then
      display_openshift_msg_ocp3
      qubinode_autoinstall_openshift
    elif [ "A${result}" == "AOKD3" ]
    then
      display_openshift_msg_okd3
      qubinode_autoinstall_okd3
    elif [ "A${result}" == "ATower" ]
    then
        setup_download_options
        qubinode_deploy_tower
    elif [ "A${result}" == "ASatellite" ]
    then
        setup_download_options
        qubinode_deploy_satellite
    elif [ "A${result}" == "AIdM" ]
    then
        setup_download_options
        qubinode_deploy_idm
    else
        echo "Unknown issue, please run the installer again"
    fi
}
