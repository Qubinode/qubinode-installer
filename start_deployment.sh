#!/usr/bin/env bash
# This script will start the automated depoyment of openshift home lab

# Uncomment for debugging
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

OPENSHIFT_RELEASE_VERSION="v3.11.98"
DEFAULT_PRODUCT="ocp"
VALID_PRODUCTS="okd ${DEFAULT_PRODUCT}"

function display_help() {
    SCRIPT=$(basename "${BASH_SOURCE[0]}")

    cat << EOH >&2
Basic usage: ${SCRIPT} [options]
    -i      Interactivly generate the inventory
    -p      Deploy okd or ocp: default is ocp
                   ---    ---             ---
    -s      Skip DNS server deployment
    -h      Display this help menu
EOH
}

function check_args () {
    if [[ $OPTARG =~ ^-[h/p/i]$ ]]
    then
      echo "Invalid option argument $OPTARG, check that each argument has a value." >&2
      exit 1
    fi
}

# misc prereqs
function setup_prereqs () {
    if [ -z "$SSH_AUTH_SOCK" ] ; then
        eval "$(ssh-agent -s)"
        test -f ~/.ssh/id_rsa && ssh-add ~/.ssh/id_rsa
    fi
}

function dns_configuration () {
    if [ "A${skip_dns}" != "Atrue" ]; then
        
        # ensure the dns_functions.sh is loaded
        if [ -f "${project_dir}/dns_server/lib/dns_functions.sh" ]; then
          source "${project_dir}/dns_server/lib/dns_functions.sh"
        else
            echo "dns_function.sh not found"; exit 1
        fi

        kvm_inventory=$1
        
        # import bootstrap_env, this file would exist if the installation
        # started for the bootable iso/usb 
        if [[ -f bootstrap_env ]]; then
            source bootstrap_env
        fi

      DOMAINNAME=$(cat "${kvm_inventory}" | grep search_domain| awk '{print $1}' | cut -d'=' -f2)
      if [ "A${DOMAINNAME}" == "A" ]; then
          echo "Please enter fill out search domain in ${kvm_inventory}"
          exit 1
      fi

        setup_prereqs
        configurednsforopenshift "${kvm_inventory}" centos
    else
        # this assumes you are providing your own dns server
        # we need to be able to do a nsupdate against your dns server
        # to verify the required dns entries are available
        echo "Do run fuction to verify dns"
        configure_dns_for_arecord $2 centos
    fi
}

function deploy_openshift () {
    configure_dns_for_arecord $2 centos
    echo -e "\e[32m************************\e[0m"
    echo -e "\e[32mDeploying Openshift vms\e[0m"
    echo -e "\e[32m************************\e[0m"
    $USESUDO ansible-playbook  -i $2 deploy_openshift_vms_centos.yml --become || exit 1
    $USESUDO  ansible-playbook -i $2 deploy_openshift_vms.yml  --become  || exit 1
    echo -e "\e[32m************************\e[0m"
    echo -e "\e[32mCreating inventory files from newly created vms\e[0m"
    echo -e "\e[32m************************\e[0m"
    bash scripts/provision_openshift_nodes.sh $2 || exit 1
}

function deploy_

function deploy_jumpbox () {
    JUMPBOX=$(cat jumpbox | tr -d '"[]",')
    echo "Generating ssh key on ${JUMPBOX}"

    scripts/generation_jumpbox_ssh_key.sh centos ${JUMPBOX}
    scripts/generation_jumpbox_ssh_key.sh  ${RHEL_USER} ${JUMPBOX}

    sharekey centos
    sharekey ${RHEL_USER}

    bash scripts/generate_openshift_inventory.sh $3 centos || exit 1
    bash scripts/generate_openshift_inventory.sh $3 rhel || exit 1

    set_arecord $2 centos inventory.3.11.${1}.gluster
    set_arecord $2 ${RHEL_USER} inventory.3.11.${1}.gluster

    ansible-playbook -i inventory.vm.provision tasks/openshift_jumpbox-v3.11.yml  --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=centos" || exit 1
    ansible-playbook -i inventory.vm.provision tasks/openshift_jumpbox-v3.11.yml --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=${RHEL_USER}"  --extra-vars="rhel_username=$RHEL_USERNAME"   --extra-vars="rhel_password=$RHEL_PASSWORD" || exit 1

    ansible-playbook -i inventory.vm.provision tasks/configure_docker_regisitry.yml --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=centos" --become || exit 1
    ansible-playbook -i inventory.vm.provision tasks/configure_docker_regisitry.yml --extra-vars "machinename=jumpboxdeploy" --extra-vars "rhel_user=${RHEL_USER}" --become || exit 1

    ansible-playbook -i inventory.vm.provision tasks/openshift_nodes-v3.11.yml --extra-vars "rhel_user=centos" || exit 1
    ansible-playbook -i inventory.vm.provision tasks/openshift_nodes-v3.11.yml --extra-vars "rhel_user=${RHEL_USER}"  --extra-vars="rhel_username=$RHEL_USERNAME" --extra-vars="rhel_password=$RHEL_PASSWORD" || exit 1

    ansible-playbook -i inventory.vm.provision tasks/openshift_gluster_config.yml  --extra-vars "rhel_user=${RHEL_USER}"   || exit 1

    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ssh-add-script.sh  centos@${JUMPBOX}:~/openshift-ansible
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ssh-add-script.sh  ${RHEL_USER}@${JUMPBOX}:~/openshift-ansible

    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no inventory.3.11.${1}.gluster  centos@${JUMPBOX}:~/openshift-ansible
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no inventory.3.11.${1}.gluster  ${RHEL_USER}@${JUMPBOX}:~/openshift-ansible

    ssh  -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${RHEL_USER}@${MASTERIP}
    mkdir ~/scripts

    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no /etc/ansible/roles/ocp-power-management/files/* ${RHEL_USER}@${MASTERIP}:~/scripts
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no start_openshift_deployment.sh ${RHEL_USER}@${JUMPBOX}:~
}

# validate product pass by user
function validate_product_by_user () {
    for item in $(echo "$VALID_PRODUCTS")
    do
        if [ "A${product}" == "A${item}" ];
        then
            product="${product}"
            break
        else
            product="${DEFAULT_PRODUCT}"
        fi
    done
}

config_err_msg () {
    cat << EOH >&2
  Could not find start_deployment.conf in the current path ${project_dir}. 
  Please make sure you are in the openshift-home-lab-directory."
EOH
}

# check for openshift-home-lab-directory and setup paths
function setup_required_paths () {
    current_dir=$(pwd)
    script_dir=$(dirname ${BASH_SOURCE[0]})
    current_dir_config="${current_dir}/inventories/inventory.kvm"
    script_dir_config="${script_dir}/inventories/inventory.kvm"

    if [ -f "${current_dir_config}" ]; then
        project_dir="${current_dir}"
        config_file="${current_dir_config}"
    elif [ ! -f "${script_dir_config}" ]; then
        project_dir="${script_dir}"
        config_file="${script_dir_config}"
    else
        config_err_msg; exit 1
    fi
}

while getopts ":hip:" opt;
do
    case $opt in
        h) display_help
           exit 1
           ;;
        i) check_args; generate_inventory=true;;
        p) check_args
           product=$OPTARG
           ;;
        s) check_args; skip_dns=true;;
       --) shift; break;;
       -*) echo Unrecognized flag : "$1" >&2
           display_help
           exit 1
           ;;
       \?) echo Unrecognized flag : "$1" >&2
           display_help
           exit 1
           ;;
    esac
done
shift "$((OPTIND-1))"

# validate user provided options
validate_product_by_user
setup_required_paths
   
echo $project_dir
echo $config_file
