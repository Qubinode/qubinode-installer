display_openshift_msg_okd4 () {
    printf "%s\n" "  ${yel}****************************************************************************${end}"
    printf "%s\n\n" "        ${cyn}${txb}OKD: The Origin Community Distribution of Kubernetes (OKD)${txend}${end}"
    printf "%s\n" "    OKD is the Origin community distribution of Kubernetes optimized for "
    printf "%s\n" "    continuous application development and multi-tenant deployment."
    printf "%s\n\n" "  ${yel}****************************************************************************${end}"

    confirm "  Do you want to proceed? yes/no"
    if [ "A${response}" == "Ayes" ]
    then
        product_opt=okd4
        ASK_SIZE=false
        setup_download_options
        qubinode_deploy_ocp4
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
    CHECK_PULL_SECRET=yes
    printf "%s\n" "  ${yel}****************************************************************************${end}"
    printf "%s\n\n" "        ${cyn}${txb}Red Hat Openshift Container Platform 4 (OCP4)${txend}${end}"
    printf "%s\n" "    The default product option is to install OCP4. The deployment consists of"
    printf "%s\n" "    ${cyn}3 ctrlplane${end} and ${cyn}3 computes${end}. It requires a minimum of ${cyn}96 Gib${end} memory and${cyn} 8 cores${end}."
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
    other_options=("OKD4 - ${cyn}Origin Community Distribution${end}" "Tower - ${cyn}Ansible Tower${end}" "IdM - ${cyn}Red Hat Identity Management${end}" "Display the help menu" "Exit the menu")
    #other_options=("${cyn}OCP4${end} - OpenShift 4" "${cyn}OKD3${end} - Origin Community Distribution" "${cyn}Tower${end} - Ansible Tower" "${cyn}Satellite${end} - Red Hat Satellite Server" "${cyn}IdM${end} - Red Hat Identity Management" "${cyn}Display the help menu${end}")


    createmenu "${other_options[@]}"
    result=($(echo "${selected_option}"))

    if [ "A${result}" == "ADisplay" ]
    then
        display_help
    elif [ "A${result}" == "AExit" ]
    then
        exit 0
    elif [ "A${result}" == "AOKD4" ]
    then
        display_openshift_msg_okd4
    elif [ "A${result}" == "ATower" ]
    then
        printf "%s\n" "        ${yel}********************************************${end}"
        printf "%s\n" "        ${cyn}${txb}Install Red Hat Ansible Tower${txend}${end}"
        printf "%s\n\n" "        ${yel}*******************************************${end}"
        confirm "  Do you want to proceed? yes/no"
        if [ "A${response}" == "Ayes" ]
        then
            CHECK_PULL_SECRET=no
            setup_download_options
            download_files
            qubinode_deploy_tower
        else
            display_other_options
        fi
    elif [ "A${result}" == "AIdM" ]
    then
        CHECK_PULL_SECRET=no
        setup_download_options
        qubinode_deploy_idm
    else
        echo "Unknown issue, please run the installer again"
    fi
}
