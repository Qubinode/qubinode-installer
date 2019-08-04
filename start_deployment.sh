#!/usr/bin/env bash
# This script will start the automated depoyment of openshift home lab

# Uncomment for debugging
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

function display_help() {
    SCRIPT=$(basename "${BASH_SOURCE[0]}")

    cat << EOH >&2
Basic usage: ${SCRIPT} [options]
    -p      Deploy okd or ocp: default is ocp
                   ---    ---             ---
    -s      Skip DNS server deployment
    -u      Skip creating DNS entries
    -h      Display this help menu
EOH
}

function check_args () {
    if [[ $OPTARG =~ ^-[h/p/u/s]$ ]]
    then
      echo "Invalid option argument $OPTARG, check that each argument has a value." >&2
      exit 1
    fi
}

function deploy_dns_server () {
    if [ "A${skip_dns}" != "Atrue" ]; then
        kvm_inventory=$1
        
        env_check
        validation $2
        addssh
        configurednsforopenshift $2 centos
        configure_dns_for_arecord $2 centos
    else
        # this assumes you are providing your own dns server
        # we need to be able to do a nsupdate against your dns server
        # to verify the required dns entries are available
        echo "Do run fuction to verify dns"
        configure_dns_for_arecord $2 centos
   fi
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
    current_dir_config="${current_dir}/inventory/group_vars/all"
    script_dir_config="${script_dir}/inventory/group_vars/all"

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

function read_sensitive_data () {
    prompt="$1"
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        if [[ $char == $'\0' ]]
        then
            break
        fi
        prompt='*'
        input+="$char"
    done
    echo "$input"
}

function rhsm_register () {
    is_registered_tmp=$(mktemp)
    subscription-manager identity > "${is_registered_tmp}" 2>&1
    is_registered=$(grep -o 'This system is not yet registered' "${is_registered_tmp}")
    if [ "A${is_registered}" == "A" ]; then
        echo "$(hostname) is registered to RHSM."
    else
        if [ "A${rhsm_reg_method}" == "Aupass" ]; 
        then
            subscription-manager register --username="$rhsm_username" --password="$rhsm_password" --force > /dev/null 2>&1
        elif [ "A${rhsm_reg_method}" == "Aakey" ]; 
        then
            subscription-manager register --org="$rhsm_org" --activationkey="$rhsm_activationkey" --force > /dev/null 2>&1
        else
            echo -n "Unknown issue: cannot register system!"
            exit 1
        fi
    
        # validate registration
        is_registered_tmp=$(mktemp)
        subscription-manager identity > "${is_registered_tmp}" 2>&1
        is_registered=$(grep -o 'This system is not yet registered' "${is_registered_tmp}")
        if [ "A${is_registered}" == "A" ]; then
            echo "Successfully registered $(hostname) to RHSM."
        else
            echo "Unsuccessfully registered $(hostname) to RHSM."
            exit 1
        fi
    
    fi
}

function setup_ansible () {
    # install python
    if [ ! -f /usr/bin/python ];
    then
       echo "installing python"
       yum install -y -q -e 0 python python3-pip python2-pip
    else
       echo "python is installed"
    fi

    # install ansible
    if [ ! -f /usr/bin/ansible ];
    then
       subscription-manager repos --list-enabled | grep rhel-7-server-ansible-2-rpms >/dev/null 2>&1 ||\
                                        subscription-manager repos --enable=rhel-7-server-ansible-2-rpms
       yum install -y -q -e 0 ansible
    else
       echo "ansible is installed"
    fi
    
    # setup vault
    if [ -f /usr/bin/ansible ];
    then
        echo "Setting up vault and encrypting vault file ${vars_file}"
        openssl rand -base64 512|xargs > ~/.vaultkey
        grep 'ANSIBLE_VAULT' "${vars_file}" >/dev/null 2>&1 ||\
          ansible-vault encrypt "${vars_file}"
        ansible-galaxy install -r "${project_dir}/playbooks/requirements.yml"
    else
        echo "Ansible not found, please install and retry."
        exit 1
    fi
        
}

function check_required_vars () {
    total=$#
    count=0
    vars="$@"

    if cat "${vars_file}"| grep -q VAULT
    then
        ansible-vault decrypt "${vars_file}"
        ansible_encrypt=yes
    fi

    for var in $vars
    do
        if grep '""' "${vars_file}"|grep -q $var
        then
            echo "checking vars"
            count=`expr $count + 1`
        #    ask_for_required_vaules
        #break
        fi
    done

    echo "total required variables are $total"
    echo "total missing is $count"

    if [ "A${ansible_encrypt}" == "Ayes" ]
    then
        ansible-vault encrypt "${vars_file}"
    fi
}

function ask_for_values () {
    read -p "Enter your dns domain or press [ENTER] for the default [lab.example]: " domain
    domain=${domain:-lab.example}

    read -p "Enter a upstream DNS server or press [ENTER] for the default [1.1.1.1]: " dns_server_public
    dns_server_public=${dns_server_public:-1.1.1.1}
}

function ask_for_vault_values () {
    unset root_user_pass
    prompt='Enter a password for the root user and press [ENTER]: '
    root_user_pass=$(read_sensitive_data "${prompt}")
    echo ""

    unset idm_admin_pwd
    prompt='Enter a password for the IDM server console and press [ENTER]: '
    idm_admin_pwd=$(read_sensitive_data "${prompt}")
    echo ""

    echo ""
    PS3="Which option are you using to register the system 'Activation Key' (akey) or Username/Pass (upass): "
    options=("akey" "upass")
    select opt in akey upass
    do
        case $opt in
            akey)
                rhsm_reg_method="$opt"
                break
                ;;
            upass)
                rhsm_reg_method="$opt"
                break
                ;;
            *)
                echo "Error: Please try again";;
            esac
        done
        
        if [ "A${rhsm_reg_method}" == "Aupass" ]; 
        then
            echo -n "Enter your RHSM username and press [ENTER]: "
            read rhsm_username
            unset rhsm_password
            prompt='Enter your RHSM password and press [ENTER]: '
            rhsm_password=$(read_sensitive_data "${prompt}")
            echo
        elif [ "A${rhsm_reg_method}" == "Aakey" ]; 
        then
            echo -n "Enter your RHSM activation key and press [ENTER]: "
            read rhsm_activationkey
            unset rhsm_org
            prompt='Enter your RHSM ORG ID and press [ENTER]: '
            rhsm_org=$(read_sensitive_data "${prompt}")
            echo
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

setup_required_paths
# setup ansible vaults varaibles
vars_file="${project_dir}/playbooks/vars/vault.yml"
vars="rhsm_reg_method root_user_pass idm_dm_pwd idm_admin_pwd"

    # Setup ansible vars
    sed -i "s/rhsm_username: \"\"/rhsm_username: "$rhsm_username"/g" "${vars_file}"
    sed -i "s/rhsm_password: \"\"/rhsm_password: "$rhsm_password"/g" "${vars_file}"
    sed -i "s/rhsm_org: \"\"/rhsm_org: "$rhsm_org"/g" "${vars_file}"
    sed -i "s/rhsm_activationkey: \"\"/rhsm_activationkey: "$rhsm_activationkey"/g" "${vars_file}"
    sed -i "s/rhsm_reg_method: \"\"/rhsm_reg_method: "$rhsm_reg_method"/g" "${vars_file}"
    sed -i "s/domain: \"\"/domain: "$domain"/g" "${vars_file}"
    sed -i "s/dns_server_public: \"\"/dns_server_public: "$dns_server_public"/g" "${vars_file}"
    sed -i "s/root_user_pass: \"\"/root_user_pass: "$root_user_pass"/g" "${vars_file}"
    sed -i "s/idm_admin_pwd: \"\"/idm_admin_pwd: "$idm_admin_pwd"/g" "${vars_file}"
    idm_dm_pwd=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)






check_required_vars $vars
rhsm_register
#setup_ansible

sed -i "s/rhsm_activationkey: \"\"/rhsm_org: "$rhsm_activationkey"/g" "${vars_file}"

# validate user provided options
validate_product_by_user
   
echo "project_dir: $project_dir"
echo "config_file: $config_file"
