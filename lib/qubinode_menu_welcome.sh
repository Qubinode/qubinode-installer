display_openshift_msg () {
    printf "%s\n" "${yel}    ****************************************************************************${end}"
    printf "%s\n" "${mag}    The default product option is to install Red Hat Openshift Container${end}"
    printf "%s\n" "${mag}    Platform 3 (OCP3). An subscription for OCP3 is required. If you do ${end}"
    printf "%s\n" "${mag}    not have an OCP3 subscription. Please choose option 2 for other product${end}"
    printf "%s\n" "${mag}    options such as OKD3. The size of your OCP3 cluster is based on your${end}"
    printf "%s\n" "${mag}    hardware profile. Hardware profiles are defined as:${end}"
    printf "%s\n" ""
    printf "%s\n" "${cyn}      Minimal     - 30G Memory and 370G Storage${end}"
    printf "%s\n" "${cyn}      Standard    - 80G Memory and 900G Storage${end}"
    printf "%s\n" "${cyn}      Performance - 88G Memory and 1340G Storage${end}"
    printf "%s\n" ""
    printf "%s\n\n" "${blu}    To deploy OCP4 you will need to meet standard hardware profile.${end}"
    printf "%s\n" "${mag}    If you wish to continue with the deployment of a OCP3 cluster, choose${end}"
    printf "%s\n" "${cyn}    Continue with the default installation${end}. ${mag}Otherwise choose${end} ${cyn}Display other options.${end}"
    printf "%s\n\n" "${yel}    ****************************************************************************${end}"
}

display_other_options () {
    printf "%s\n\n" ""
    #other_options=("${cyn}OCP4${end} - OpenShift 4" "${cyn}OKD3${end} - Origin Community Distribution" "${cyn}Tower${end} - Ansible Tower" "${cyn}Satellite${end} - Red Hat Satellite Server" "${cyn}IdM${end} - Red Hat Identity Management" "${cyn}Display the help menu${end}")

    other_options=("OCP4 - OpenShift 4" "OKD3 - Origin Community Distribution" "Tower - Ansible Tower" "Satellite - Red Hat Satellite Server" "IdM - Red Hat Identity Management" "Display the help menu")

    createmenu "${other_options[@]}"
    result=($(echo "${selected_option}"))

    if [ "A${result}" == "ADisplay" ]
    then
        display_help
    elif [ "A${result}" == "AOCP4" ]
    then
        qubinode_autoinstall_openshift4
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
