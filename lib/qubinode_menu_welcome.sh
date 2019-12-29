display_openshift_msg () {
    printf "%s\n" "${yel}    ****************************************************************************${end}"
    printf "%s\n" "${mag}    The default product option is to install Red Hat Openshift Container${end}"
    printf "%s\n" "${mag}    Platform (OCP). An subscription for OCP is required. If you do not have an${end}"
    printf "%s\n" "${mag}    OCP subscription. Please display the menu options for other product${end}"
    printf "%s\n" "${mag}    installation such as OKD. The OCP cluster deployment consist of:${end}"
    printf "%s\n" ""
    printf "%s\n" "${cyn}      - 1 IDM server for DNS${end}"
    printf "%s\n" "${cyn}      - 1 Master node${end}"
    printf "%s\n" "${cyn}      - 2 App nodes${end}"
    printf "%s\n" "${cyn}      - 2 Infra nodes${end}"
    printf "%s\n" ""
    printf "%s\n" "${blu}    Gluster is deployed as the container storage running on the infra and app${end}"
    printf "%s\n\n" "${blu}    nodes.${end}"
    printf "%s\n" "${mag}    If you wish to continue with this install choose the **continue** option${end}"
    printf "%s\n" "${mag}    otherwise display the help menu to see the available options.${end}"
    printf "%s\n\n" "${yel}    ****************************************************************************${end}"
}

display_other_options () {
    printf "%s\n\n" ""
    other_options=("${cyn}OCP4${end} - OpenShift 4" "${cyn}OKD3${end} - Origin Community Distribution" "${cyn}Tower${end} - Ansible Tower" "${cyn}Satellite${end} - Red Hat Satellite Server" "${cyn}IdM${end} - Red Hat Identity Management" "${cyn}Display the help menu${end}")
    createmenu "${other_options[@]}"
    result=($(echo "${selected_option}"))
    if [ "A${result}" == "ADisplay" ]
    then
        display_help
    elif [ "A${result}" == "AOCP4" ]
    then
        openshift4_enterprise_deployment
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
        echo $result
        echo "Unknown issue, please run the installer again"
    fi
}
