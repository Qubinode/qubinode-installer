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
    printf "%s\n" "${yel}    ****************************************************************************${end}"
    printf "%s\n" "${mag}    The default product option is to install Red Hat Openshift Container${end}"
    printf "%s\n" "${mag}    Platform 4 (OCP4)."
    printf "%s\n" ""
    printf "%s\n\n" "${blu}    To deploy OCP4 you will need to meet standard hardware profile.${end}"
    printf "%s\n" "${mag}    If you wish to continue with the deployment of a OCP3 cluster, choose option 2${end}"
    printf "%s\n" "${cyn}    Continue with the default installation${end}. ${mag}Otherwise choose${end} ${cyn}Display other options.${end}"
    printf "%s\n\n" "${yel}    ****************************************************************************${end}"
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
