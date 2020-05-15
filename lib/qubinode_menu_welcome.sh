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
    printf "%s\n" "    3 masters and 3 computes. The ${cyn}${txb}standard hardware profile is the minimum${txend}${end}"
    printf "%s\n" "    hardware profile required for the installation. In addition to meeting the"
    printf "%s\n" "    minimum hardware profile requirement, the installation requires a valid"
    printf "%s\n" "    pull-secret. If you are unable to obtain a pull-secret, exit the install"
    printf "%s\n\n" "    and choose OKD from menu option 2."
    printf "%s\n" "    Hardware profiles are defined as:"
    display_hardware_profile_msg
    printf "%s\n\n" "  ${yel}****************************************************************************${end}"

    default_message=("Continue with the default installation" "Display other options")
    createmenu "${default_message[@]}"
    result=($(echo "${selected_option}"))
    if [ "A${result}" == "ADisplay" ]
    then
        display_other_options
    elif [ "A${result}" == "AContinue" ]
    then
        ASK_SIZE=false
        qubinode_deploy_ocp4
    else
        print "%s\n" " ${red}Unknown issue, please run the installer again${end}"
    fi
}


display_other_options () {
    printf "%s\n\n" ""
    #other_options=("${cyn}OCP4${end} - OpenShift 4" "${cyn}OKD3${end} - Origin Community Distribution" "${cyn}Tower${end} - Ansible Tower" "${cyn}Satellite${end} - Red Hat Satellite Server" "${cyn}IdM${end} - Red Hat Identity Management" "${cyn}Display the help menu${end}")

    other_options=("OCP3 - OpenShift 3" "OKD3 - Origin Community Distribution" "Tower - Ansible Tower" "Satellite - Red Hat Satellite Server" "IdM - Red Hat Identity Management" "Display the help menu")

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
        echo "Not implemented yet!"
    elif [ "A${result}" == "ATower" ]
    then
        qubinode_deploy_tower
    elif [ "A${result}" == "ASatellite" ]
    then
        qubinode_deploy_satellite
    elif [ "A${result}" == "AIdM" ]
    then
        qubinode_deploy_idm
    else
        echo "Unknown issue, please run the installer again"
    fi
}
