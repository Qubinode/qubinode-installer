#!/usr/bin/env bash
# This script will start the automated depoyment of openshift home lab

# Uncomment for debugging
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

function display_help() {
    SCRIPT=$(basename "${BASH_SOURCE[0]}")
    cat << EOH >&2

Basic usage: ${SCRIPT} [options]
    -p      Deploy a container platform - options are:
                okd - deploy upstream openshift
                ocp - deploy Red Hat OpenShift Platform <subscription required>    
    
    -c      Clean up project directory

    -b      DNS operations - options are:
              server  - install dns server
              records - create dns records 

    -k      Run kvm host setup - options are
                skip - don't run setup
                setup - run the setup

    -d      VMs operations - options are
                deploy   - deploy all vms
                undeploy - delete all vms
                skip     - delete all vms

    -h      Display this help menu

EOH

}

# validates that the argument options are valid
# e.g. if script -s-p pass, it won't use '-' as 
# an argument for -s
function check_args () {
    if [[ $OPTARG =~ ^-[h/p/u/s]$ ]]
    then
      echo "Invalid option argument $OPTARG, check that each argument has a value." >&2
      exit 1
    fi
}

# not in used: this should be the function
# that asked the user if they want to install
# openshift or OKD
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

# just shows the below error message
config_err_msg () {
    cat << EOH >&2
  Could not find start_deployment.conf in the current path ${project_dir}. 
  Please make sure you are in the openshift-home-lab-directory."
EOH
}

# this function just make sure the script
# knows the full path to the project directory
# and runs the config_err_msg if it can't determine
# that start_deployment.conf can find the project directory
function setup_required_paths () {
    project_dir="`dirname \"$0\"`"
    project_dir="`( cd \"$project_dir\" && pwd )`"
    if [ -z "$project_dir" ] ; then
        config_err_msg; exit 1
    fi

    if [ ! -d "${project_dir}/playbooks/vars" ] ; then
        config_err_msg; exit 1
    fi
}

# this configs prints out asterisks when sensitive data
# is being entered
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

# this function checks if the system is registered to RHSM
# validate the registration or register the system
# if it's not registered
function rhsm_register () {
    is_registered_tmp=$(mktemp)
    sudo subscription-manager identity > "${is_registered_tmp}" 2>&1
    is_registered=$(grep -o 'This system is not yet registered' "${is_registered_tmp}")
    if [ "A${is_registered}" == "A" ]; then
        echo "$(hostname) is registered to RHSM."
    else
        if [ "A${rhsm_reg_method}" == "Aupass" ]; 
        then
            sudo subscription-manager register --username="$rhsm_username" --password="$rhsm_password" --force > /dev/null 2>&1
        elif [ "A${rhsm_reg_method}" == "Aakey" ]; 
        then
            sudo subscription-manager register --org="$rhsm_org" --activationkey="$rhsm_activationkey" --force > /dev/null 2>&1
        else
            echo -n "Unknown issue: cannot register system!"
            exit 1
        fi
    
        # validate registration
        is_registered_tmp=$(mktemp)
        sudo subscription-manager identity > "${is_registered_tmp}" 2>&1
        is_registered=$(grep -o 'This system is not yet registered' "${is_registered_tmp}")
        if [ "A${is_registered}" == "A" ]; then
            echo "Successfully registered $(hostname) to RHSM."
        else
            echo "Unsuccessfully registered $(hostname) to RHSM."
            exit 1
        fi
    
    fi
}

# this function make sure Ansible is installed
# along with any other dependancy the project
# depends on
function setup_ansible () {
    vaultfile=$1

    # install python
    if [ ! -f /usr/bin/python ];
    then
       echo "installing python"
       sudo yum install -y -q -e 0 python python3-pip python2-pip python-dns
    else
       echo "python is installed"
    fi

    # install ansible
    if [ ! -f /usr/bin/ansible ];
    then
       if ! sudo subscription-manager repos --list-enabled | grep -q "${ANSIBLE_REPO}"
       then
           sudo subscription-manager repos --enable="${ANSIBLE_REPO}"
       fi
       sudo yum install -y -q -e 0 ansible
    else
       echo "ansible is installed"
    fi
    
    # setup vault
    if [ -f /usr/bin/ansible ];
    then
        if [ ! -f "${vault_key_file}" ]
        then
            echo "Create ansible-vault password file ${vault_key_file}"
            openssl rand -base64 512|xargs > "${vault_key_file}"
        fi
    
        if cat "${vaultfile}" | grep -q VAULT 
        then
            echo "${vaultfile} is encrypted"
        else
            echo "Encrypting ${vaultfile}"
            ansible-vault encrypt "${vaultfile}"
        fi

        # Ensure roles are downloaded
        echo ""
        echo "Downloading required roles"
        #ansible-galaxy install -r "${project_dir}/playbooks/requirements.yml" > /dev/null 2>&1
        ansible-galaxy install --force -r "${project_dir}/playbooks/requirements.yml"
        echo ""
        echo ""

        # Ensure required modules are downloaded
        if [ ! -f "${project_dir}/modules/redhat_repositories.py" ]
        then
            test -d "${project_dir}/modules" || mkdir "${project_dir}/modules"
            CURRENT_DIR=$(pwd)
            cd "${project_dir}/modules/"
            wget https://raw.githubusercontent.com/jfenal/ansible-modules-jfenal/master/packaging/os/redhat_repositories.py
            cd "${CURRENT_DIR}"
        fi
    else
        echo "Ansible not found, please install and retry."
        exit 1
    fi
        
}

# generic user choice menu
# this should eventually be used anywhere we need
# to provide user with choice
createmenu () {
    select selected_option; do # in "$@" is the default
        if [ "$REPLY" -eq "$REPLY" 2>/dev/null ]
        then
            if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $(($#)) ]; then
                break;
            else
                echo "Please make a vaild selection (1-$#)."
            fi
         else
            echo "Please make a vaild selection (1-$#)."
         fi
    done
}

# This is where we prompt users for answers to
# keys we have predefined. Any senstive data is
# collected using a different function
function ask_for_values () {
    varsfile=$1
    
    # ask user for DNS domain or use default
    if grep '""' "${varsfile}"|grep -q domain
    then
        read -p "Enter your dns domain or press [ENTER] for the default [lab.example]: " domain
        domain=${domain:-lab.example}
        sed -i "s/domain: \"\"/domain: "$domain"/g" "${varsfile}"
    fi

    # ask user for public DNS server or use default
    if grep '""' "${varsfile}"|grep -q dns_server_public
    then
        read -p "Enter a upstream DNS server or press [ENTER] for the default [1.1.1.1]: " dns_server_public
        dns_server_public=${dns_server_public:-1.1.1.1}
        sed -i "s/dns_server_public: \"\"/dns_server_public: "$dns_server_public"/g" "${varsfile}"
    fi

    # ask user for their IP network and use the default
    if cat "${varsfile}"|grep -q changeme.in-addr.arpa
    then
        read -p "Enter your IP Network or press [ENTER] for the default [$NETWORK]: " network
        network=${network:-"${NETWORK}"}
        PTR=$(echo "$NETWORK" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'|sed 's/0.//g')
        sed -i "s/changeme.in-addr.arpa/"$PTR"/g" "${varsfile}"
    fi

    # ask user to choose which libvirt network to use
    if grep '""' "${varsfile}"|grep -q vm_libvirt_net
    then
        declare -a networks=()
        mapfile -t networks < <(sudo virsh net-list --name|sed '/^[[:space:]]*$/d')
        createmenu "${networks[@]}"
        network=($(echo "${selected_option}"))
        sed -i "s/vm_libvirt_net: \"\"/vm_libvirt_net: "$network"/g" "${varsfile}"
    fi

    
}

function ask_for_vault_values () {
    vaultfile=$1

cat << EOH >&2

 The following prompts will ask you values that are required for the installation
 to continue. If you make a mistake when entering passwords, pressing the Backspace 
 key will not fix it. Just hit Ctrl+c to cancel and run this script again.

EOH

    if cat "${vaultfile}"| grep -q VAULT
    then
        test -f /usr/bin/ansible-vault && ansible-vault decrypt "${vaultfile}"
        ansible_encrypt=yes
    fi

    if grep '""' "${vaultfile}"|grep -q idm_dm_pwd
    then
        idm_dm_pwd=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
        sed -i "s/idm_dm_pwd: \"\"/idm_dm_pwd: "$idm_dm_pwd"/g" "${vaultfile}"
    fi

    if grep '""' "${vaultfile}"|grep -q root_user_pass
    then
        unset root_user_pass
        prompt='Enter a password for the root user and press [ENTER]: '
        root_user_pass=$(read_sensitive_data "${prompt}")
        sed -i "s/root_user_pass: \"\"/root_user_pass: "$root_user_pass"/g" "${vaultfile}"
        echo ""
    fi

    if grep '""' "${vaultfile}"|grep -q idm_admin_pwd
    then
        unset idm_admin_pwd
        prompt='Enter a password for the IDM server console and press [ENTER]: '
        idm_admin_pwd=$(read_sensitive_data "${prompt}")
        sed -i "s/idm_admin_pwd: \"\"/idm_admin_pwd: "$idm_admin_pwd"/g" "${vaultfile}"
        echo ""
    fi

    if grep '""' "${vaultfile}"|grep -q rhsm_reg_method
    then
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
                sed -i "s/rhsm_username: \"\"/rhsm_username: "$rhsm_username"/g" "${vaultfile}"
                sed -i "s/rhsm_password: \"\"/rhsm_password: "$rhsm_password"/g" "${vaultfile}"
                echo
            elif [ "A${rhsm_reg_method}" == "Aakey" ]; 
            then
                echo -n "Enter your RHSM activation key and press [ENTER]: "
                read rhsm_activationkey
                unset rhsm_org
                prompt='Enter your RHSM ORG ID and press [ENTER]: '
                rhsm_org=$(read_sensitive_data "${prompt}")
                sed -i "s/rhsm_org: \"\"/rhsm_org: "$rhsm_org"/g" "${vaultfile}"
                sed -i "s/rhsm_activationkey: \"\"/rhsm_activationkey: "$rhsm_activationkey"/g" "${vaultfile}"
                echo
            fi
            sed -i "s/rhsm_reg_method: \"\"/rhsm_reg_method: "$rhsm_reg_method"/g" "${vaultfile}"
    fi

    if [ "A${ansible_encrypt}" == "Ayes" ]
    then
        test -f /usr/bin/ansible-vault && ansible-vault encrypt "${vaultfile}"
    fi
}

function prereqs () {
    # setup required paths
    setup_required_paths
    # setup MAIN variables
    CURRENT_USER=$(whoami)
    vault_key_file="/home/${CURRENT_USER}/.vaultkey"
    vault_vars_file="${project_dir}/playbooks/vars/vault.yml"
    vars_file="${project_dir}/playbooks/vars/all.yml"
    hosts_inventory_dir="${project_dir}/inventory"
    inventory_file="${hosts_inventory_dir}/hosts"
    IPADDR=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    # HOST Gateway not currently in use
    GTWAY=$(ip route get 8.8.8.8 | awk -F"via " 'NR==1{split($2,a," ");print a[1]}')
    NETWORK=$(ip route | awk -F'/' "/$IPADDR/ {print \$1}")
    PTR=$(echo "$NETWORK" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'|sed 's/0.//g')
    ANSIBLE_REPO=rhel-7-server-ansible-2-rpms
}

function always_run () {
    if [ "A${CURRENT_USER}" != "Aroot" ]
    then
        echo "Checking if password less suoders is setup for ${CURRENT_USER}."
        sudo test -f "/etc/sudoers.d/${CURRENT_USER}"
        if [ "A$?" != "A0" ]
        then
            echo "Setting up /etc/sudoers.d/${CURRENT_USER}"
            echo "Please enter the password for the root user at the prompt."
            echo ""
            su root -c "echo '${CURRENT_USER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${CURRENT_USER}"
       fi
    fi

    # copy sample vars file to playbook/vars directory
    if [ ! -f "${vars_file}" ]
    then
      cp "${project_dir}/samples/all.yml" "${vars_file}"
    fi

    # create vault vars file
    if [ ! -f "${vault_vars_file}" ]
    then
        cat > "${vault_vars_file}" <<EOF
rhsm_username: ""
rhsm_password: ""
rhsm_org: ""
rhsm_activationkey: ""
rhsm_reg_method: ""
root_user_pass: ""
idm_ssh_user: root
idm_dm_pwd: ""
idm_admin_pwd: ""
EOF
    fi

    # create ansible inventory file
    if [ ! -f "${hosts_inventory_dir}/hosts" ]
    then
        cat > "${hosts_inventory_dir}/hosts" <<EOF
localhost               ansible_connection=local ansible_user=root
[ocp]
EOF
    fi

    # add inventory file to all.yml
    if grep '""' "${vars_file}"|grep -q inventory_file
    then
        echo "need to update inventory"
        sed -i "s#inventory_file: \"\"#inventory_file: "$inventory_file"#g" "${vars_file}"
    fi

    echo ""
    echo "#************************************************#"
    echo "# Collecting values for ${vars_file} #"
    echo "#************************************************#"
    echo ""
    ask_for_values "${vars_file}"
    ask_for_vault_values "${vault_vars_file}"
    rhsm_register
    setup_ansible "${vault_vars_file}"
}

function setup_kvm_host () {
    # Run playbook to setup host
    if [ "A${kvm_host}" == "Atrue" ]
    then
        if [ "A${kvm_host_opt}" == "Asetup" ]
        then
            always_run
            ansible-playbook "${project_dir}/playbooks/setup_kvmhost.yml"
        elif [ "A${kvm_host_opt}" == "Askip" ]
            then
            echo "Skipping running ${project_dir}/playbooks/setup_kvmhost.yml"
        else
           display_help
        fi
    fi
}

echo ""
echo ""
OPTIND=1
NUM_ARGS="$#"

if [ "${NUM_ARGS}" == "0" ]
then
    deploy='Deploy the default OpenShift Cluster'
    display='Display Help'
    declare -a options=("${deploy}" "${display}")
    createmenu "${options[@]}"
    option=($(echo "${selected_option}"))
    if [ "${option}" == "Deploy" ]
    then
        NUM_ARGS=1
        check=true
        kvm_host=true
        kvm_host_opt=setup
        deploy_vm=true
        deploy_vm_opt=deploy
        dns=true
        dns_opt=server
    elif [ "${option}" == "Display" ]
    then
        echo "displaying help"
        display_help
        exit
    else
        exit
    fi
fi

while getopts ":hck:p:d:b:" opt;
do
    case $opt in
        h) display_help
           exit 1
           ;;
        c) check_args; 
           clean_project=true
           check=true
           ;;
        k) check_args;
           check=true
           kvm_host=true
           kvm_host_opt=$OPTARG
           ;;
        d) check_args;
           check=true
           deploy_vm_opt=$OPTARG
           deploy_vm="true"
           ;;
        b) check_args;
           check=true
           dns=true
           dns_opt=$OPTARG
           ;;
        p) check_args
           check=true
           product=true
           product=$OPTARG
           ;;
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


##############################
##       MAIN               ##
##############################

if [ "${NUM_ARGS}" != "0" ] && [ "A${check}" != "A" ]
then
    # run pre flight
    prereqs

    # check for clean up argument
    if [ "A${clean_project}" == "Atrue" ]
    then
       rm -f "${vault_vars_file}"
       rm -f "${vars_file}"
       rm -f "${hosts_inventory_dir}/*"
    fi

    setup_kvm_host 

   # Deploy VMS
   if [ "A${deploy_vm}" == "Atrue" ]
   then
       echo "running deploy vm fucntion"
       if [ "A${deploy_vm_opt}" == "Adeploy" ]
       then
           always_run
           if grep vm_teardown "${vars_file}"|grep -q true
           then
               sed -i "s/^vm_teardown: true/vm_teardown: false/g" "${vars_file}"
           fi
           ansible-playbook "${project_dir}/playbooks/deploy_vms.yml"
        elif [ "A${deploy_vm_opt}" == "Aundeploy" ]
        then
            always_run
            if grep vm_teardown "${vars_file}"|grep -q false
            then
                sed -i "s/^vm_teardown: false/vm_teardown: true/g" "${vars_file}"
            fi
            ansible-playbook "${project_dir}/playbooks/deploy_vms.yml" --extra-vars "vm_teardown=true"
        elif [ "A${deploy_vm_opt}" == "Askip" ]
        then
            echo "Skipping running ${project_dir}/playbooks/deploy_vms.yml"
        else
            display_help
        fi
    fi
    
    # Deploy IDM server
    if [ "A${dns}" == "Atrue" ]
    then
        if [ "A${dns_opt}" == "Aserver" ]
        then
            always_run
            echo "UPDATING idm_public_ip"
            SRV_IP=$(awk -F'=' '/dns01/ {print $2}' "${project_dir}/inventory/hosts"|awk '{print $1}' |sed 's/[[:blank:]]//g')
            #sed -i "s/idm_public_ip: \"\"/idm_public_ip: "$SRV_IP"/g" "${vars_file}"
            echo "Updating idm_public_ip to $SRV_IP"
            #sed -i "s/^idm_public_ip:.*\"\"/idm_public_ip: "$SRV_IP"/g" "${vars_file}"
            sed -i "s/^idm_public_ip:.*/idm_public_ip: "$SRV_IP"/g" "${vars_file}"
            ansible-playbook "${project_dir}/playbooks/idm_server.yml"
            ansible-playbook "${project_dir}/playbooks/add-idm-records.yml"
        elif [ "A${dns_opt}" == "Arecords" ]
        then
            ansible-playbook "${project_dir}/playbooks/add-idm-records.yml"
        else
           display_help
        fi
    fi
else
    display_help
fi

exit 0
