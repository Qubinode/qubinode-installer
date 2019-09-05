function display_help() {
    setup_required_paths
    SCRIPT="$0"
    cat < "${project_dir}/docs/qubinode-install.adoc"
}

# The functions is_root, has_sudo and elevate_cmd was taken from https://bit.ly/2H42ppN
# These functions are use to elevate a regular using either sudo or the root user password
function is_root () {
    return $(id -u)
}

function has_sudo() {
    local prompt

    prompt=$(sudo -nv 2>&1)
    if [ $? -eq 0 ]; then
    echo "has_sudo__pass_set"
    elif echo $prompt | grep -q '^sudo:'; then
    echo "has_sudo__needs_pass"
    else
    echo "no_sudo"
    fi
}

function elevate_cmd () {
    local cmd=$@

    HAS_SUDO=$(has_sudo)

    case "$HAS_SUDO" in
    has_sudo__pass_set)
        sudo $cmd
        ;;
    has_sudo__needs_pass)
        #echo "Please supply sudo password for the following command: sudo $cmd"
        sudo $cmd
        ;;
    *)
        echo "Please supply root password for the following command: su -c \"$cmd\""
        su -c "$cmd"
        ;;
    esac
}


# validates that the argument options are valid
# e.g. if script -s-p pass, it won't use '-' as
# an argument for -s
function check_args () {
    if [[ $OPTARG =~ ^-[p/c/h/d/a/v/m]$ ]]
    then
      echo "Invalid option argument $OPTARG, check that each argument has a value." >&2
      exit 1
    fi
}


# just shows the below error message
function config_err_msg () {
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
    # based on shorturl.at/BEHY3
    sensitive_data=''
    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && { printf '\n'; break; } # ENTER pressed; output \n and break.
      if [[ $char == $'\x7f' ]]; then # backspace was pressed
          # Remove last char from output variable.
          [[ -n $sensitive_data ]] && sensitive_data=${sensitive_data%?}
          # Erase '*' to the left.
          printf '\b \b'
      else
        # Add typed char to output variable.
        sensitive_data+=$char
        # Print '*' in its stead.
        printf '*'
      fi
    done
}

# Ensure RHEL is set to the supported release
function set_rhel_release () {
    RHEL_RELEASE=$(awk '/rhel_release/ {print $2}' samples/all.yml |grep [0-9])
    RELEASE="Release: ${RHEL_RELEASE}"
    CURRENT_RELEASE=$(sudo subscription-manager release --show)

    if [ "A${RELEASE}" != "A${CURRENT_RELEASE}" ]
    then
        echo "Setting RHEL to the supported release: ${RHEL_RELEASE}"
        sudo subscription-manager release --unset
        sudo subscription-manager release --set="${RHEL_RELEASE}"
    else
       echo "RHEL release is set to the supported release: ${CURRENT_RELEASE}"
    fi
}

function check_for_dns () {
    record=$1
    if [ -f /usr/bin/dig ]
    then
        resolvedIP=$(nslookup "$record" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
    elif [ -f /usr/bin/nslookup ]
    then
        resolvedIP=$(dig +short "$record")
    else
        echo "Can't find the dig or nslookup command, please resolved and run script again"
        exit 1
    fi

    if [ "A${resolvedIP}" == "A" ]
    then
        echo "DNS resolution for $record failed!"
        echo "Please ensure you have access to the internet or /etc/resolv.conf has the correct entries"
        exit 1
    fi
}

# check if a given or given files exist
function does_file_exist () {
    exist=()
    for f in $(echo "$@")
    do
        if [ -f $f ]
        then
            exist=("${exist[@]}" "$f")
        fi
    done

    if [ ${#exist[@]} -ne 0 ]
    then
        echo "yes"
    else
        echo "no"
    fi
}

# This function checks the status of RHSM registration
function check_rhsm_status () {

    sudo subscription-manager identity > /dev/null 2>&1
    RESULT="$?"
    if [ "A${RESULT}" == "A1" ]
    then
        echo "This system is not yet registered"
        echo "Please run qubinode-installer -m rhsm"
        echo ""
        exit 1
    fi

    status_result=$(mktemp)
    sudo subscription-manager status > "${status_result}" 2>&1
    status=$(awk -F: '/Overall Status:/ {print $2}' "${status_result}"|sed 's/^ *//g')
    if [ "A${status}" != "ACurrent" ]
    then
        sudo subscription-manager refresh
        sudo subscription-manager attach --auto
    fi

    #check again
    sudo subscription-manager status > "${status_result}" 2>&1
    status=$(awk -F: '/Overall Status:/ {print $2}' "${status_result}"|sed 's/^ *//g')
    if [ "A${status}" != "ACurrent" ]
    then
        echo "Cannot resolved $(hostname) subscription status"
        echo "Error details are: "
        cat "${status_result}"
        echo ""
        echo "Please resolved and try again"
        echo ""
        exit 1
    fi
}

function check_for_hash () {
    if [ -n $string ] && [ `expr "$string" : '[0-9a-fA-F]\{32\}\|[0-9a-fA-F]\{40\}'` -eq ${#string} ]
    then
        echo "valid"
    else
        echo "invalid"
    fi
}

# this function checks if the system is registered to RHSM
# validate the registration or register the system
# if it's not registered
function qubinode_rhsm_register () {
    prereqs
    vaultfile="${vault_vars_file}"
    varsfile="${vars_file}"
    does_exist=$(does_file_exist "${vault_vars_file} ${vars_file}")
    if [ "A${does_exist}" == "Ano" ]
    then
        echo "The file ${vars_file} and ${vault_vars_file} does not exist"
        echo ""
        echo "Try running: qubinode-installer -m setup"
        echo ""
        exit 1
    fi

    RHEL_RELEASE=$(awk '/rhel_release/ {print $2}' "${vars_file}" |grep [0-9])
    IS_REGISTERED_tmp=$(mktemp)
    sudo subscription-manager identity > "${IS_REGISTERED_tmp}" 2>&1

    # decrypt ansible vault
    decrypt_ansible_vault "${vault_vars_file}"

    # Gather subscription infomration
    rhsm_reg_method=$(awk '/rhsm_reg_method/ {print $2}' "${vars_file}")
    if [ "A${rhsm_reg_method}" == "AUsername" ]
    then
        rhsm_msg="Registering system to rhsm using your username/password"
        rhsm_username=$(awk '/rhsm_username/ {print $2}' "${vaultfile}")
        rhsm_password=$(awk '/rhsm_password/ {print $2}' "${vaultfile}")
        rhsm_cmd_opts="--username='${rhsm_username}' --password='${rhsm_password}'"
    elif [ "A${rhsm_reg_method}" == "AActivation" ]
    then
        rhsm_msg="Registering system to rhsm using your activaiton key"
        rhsm_org=$(awk '/rhsm_org/ {print $2}' "${vaultfile}")
        rhsm_activationkey=$(awk '/rhsm_activationkey/ {print $2}' "${vaultfile}")
        rhsm_cmd_opts="--org='${rhsm_org}' --activationkey='${rhsm_activationkey}'"
    else
        echo "The value of rhsm_reg_method in "${vars_file}" is not a valid value."
        echo "Valid options are 'Activation' or 'Username'."
        echo ""
        echo "Try running: qubinode-installer -m setup"
        echo ""
        exit 1
    fi

    #encrupt vault file
    encrypt_ansible_vault "${vault_vars_file}"

    IS_REGISTERED=$(grep -o 'This system is not yet registered' "${IS_REGISTERED_tmp}")
    if [ "A${IS_REGISTERED}" == "AThis system is not yet registered" ]
    then
        check_for_dns subscription.rhsm.redhat.com
        echo "${rhsm_msg}"
        rhsm_reg_result=$(mktemp)
        echo sudo subscription-manager register "${rhsm_cmd_opts}" --force --release="'${RHEL_RELEASE}'"|sh > "${rhsm_reg_result}" 2>&1
        RESULT="$?"
        if [ "A${RESULT}" == "A${RESULT}" ]
        then
            echo "Successfully registered $(hostname) to RHSM"
            cat "${rhsm_reg_result}"
            check_rhsm_status
            set_openshift_rhsm_pool_id
        else
            echo "$(hostname) registration to RHSM was unsuccessfull"
            cat "${rhsm_reg_result}"
        fi
    else
        echo "$(hostname) is already registered"
        check_rhsm_status
        set_openshift_rhsm_pool_id
    fi

}

# this function make sure Ansible is installed
# along with any other dependancy the project
# depends on
function qubinode_setup_ansible () {
    prereqs
    vaultfile="${vault_vars_file}"
    HAS_SUDO=$(has_sudo)
    if [ "A${HAS_SUDO}" == "Ano_sudo" ]
    then
        echo "You do not have sudo access"
        echo "Please run qubinode-installer -m setup"
        exit 1
    fi
    check_rhsm_status

    # install python
    if [ ! -f /usr/bin/python ];
    then
       echo "installing python"
       sudo yum clean all > /dev/null 2>&1
       sudo yum install -y -q -e 0 python python3-pip python2-pip python-dns
    else
       echo "python is installed"
    fi

    # install ansible
    if [ ! -f /usr/bin/ansible ];
    then
       ANSIBLE_REPO=$(awk '/ansible_repo:/ {print $2}' "${vars_file}")
       CURRENT_REPO=$(sudo subscription-manager repos --list-enabled| awk '/ID:/ {print $3}'|grep ansible)
       # check to make sure the support ansible repo is enabled
       if [ "A${CURRENT_REPO}" != "A${ANSIBLE_REPO}" ]
       then
           sudo subscription-manager repos --disable="${CURRENT_REPO}"
           sudo subscription-manager repos --enable="${ANSIBLE_REPO}"
       fi
       sudo yum clean all > /dev/null 2>&1
       sudo yum install -y -q -e 0 ansible git
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
        ansible-galaxy install --force -r "${project_dir}/playbooks/requirements.yml" || exit $?
        echo ""
        echo ""

        # Ensure required modules are downloaded
        if [ ! -f "${project_dir}/playbooks/modules/redhat_repositories.py" ]
        then
            test -d "${project_dir}/playbooks/modules" || mkdir "${project_dir}/playbooks/modules"
            CURRENT_DIR=$(pwd)
            cd "${project_dir}/playbooks/modules/"
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
function createmenu () {
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

    # # ask user to choose which libvirt network to use
    # if grep '""' "${varsfile}"|grep -q vm_libvirt_net
    # then
    #     declare -a networks=()
    #     mapfile -t networks < <(sudo virsh net-list --name|sed '/^[[:space:]]*$/d')
    #     createmenu "${networks[@]}"
    #     network=($(echo "${selected_option}"))
    #     sed -i "s/vm_libvirt_net: \"\"/vm_libvirt_net: "$network"/g" "${varsfile}"
    # fi
}

function get_rhsm_user_and_pass () {
    if grep '""' "${vault_vars_file}"|grep -q rhsm_username
    then
        echo -n "Enter your RHSM username and press [ENTER]: "
        read rhsm_username
        sed -i "s/rhsm_username: \"\"/rhsm_username: "$rhsm_username"/g" "${vaulted_file}"
    fi
    if grep '""' "${vault_vars_file}"|grep -q rhsm_password
    then
        unset rhsm_password
        echo -n 'Enter your RHSM password and press [ENTER]: '
        read_sensitive_data
        rhsm_password="${sensitive_data}"
        sed -i "s/rhsm_password: \"\"/rhsm_password: "$rhsm_password"/g" "${vaulted_file}"
    fi
}

function decrypt_ansible_vault () {
    vaulted_file="$1"
    grep -q VAULT "${vaulted_file}"
    if [ "A$?" == "A1" ]
    then
        #echo "${vaulted_file} is not encrypted"
        :
    else
        test -f /usr/bin/ansible-vault && ansible-vault decrypt "${vaulted_file}"
        ansible_encrypt=yes
    fi
}

function encrypt_ansible_vault () {
    vaulted_file="$1"
    if [ "A${ansible_encrypt}" == "Ayes" ]
    then
        test -f /usr/bin/ansible-vault && ansible-vault encrypt "${vaulted_file}"
    fi
}

function ask_for_vault_values () {
    vaultfile=$1
    varsfile=$2

    # decrypt ansible vault file
    decrypt_ansible_vault "${vaultfile}"

    # Generate a ramdom password for IDM directory manager
    # This will not prompt the user
    if grep '""' "${vaultfile}"|grep -q idm_dm_pwd
    then
        idm_dm_pwd=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
        sed -i "s/idm_dm_pwd: \"\"/idm_dm_pwd: "$idm_dm_pwd"/g" "${vaultfile}"
    fi

    # root user password to be set for virtual instances created
    if grep '""' "${vaultfile}"|grep -q admin_user_password
    then
        unset admin_user_password
        echo -n "Your username ${CURRENT_USER} will be used to ssh into all the VMs created."
        echo -n "Enter a password for ${CURRENT_USER} [ENTER]: "
        read_sensitive_data
        admin_user_password="${sensitive_data}"
        sed -i "s/admin_user_password: \"\"/admin_user_password: "$admin_user_password"/g" "${vaultfile}"
        echo ""
    fi

    # This is the password used to log into the IDM server webconsole and also the admin user
    if grep '""' "${vaultfile}"|grep -q idm_admin_pwd
    then
        unset idm_admin_pwd
        while [[ ${#idm_admin_pwd} -lt 8 ]]
        do
            echo -n 'Enter a password for the IDM server console and press [ENTER]: '
            read_sensitive_data
            idm_admin_pwd="${sensitive_data}"
            if [ ${#idm_admin_pwd} -lt 8 ]
            then
                echo "Important: Password must be at least 8 characters long."
                echo "Password must be at least 8 characters long"
                echo "Please re-run the installer"
            fi
        done
        sed -i "s/idm_admin_pwd: \"\"/idm_admin_pwd: "$idm_admin_pwd"/g" "${vaultfile}"
        echo ""
        #fi
    fi

    if grep '""' "${vars_file}"|grep -q rhsm_reg_method
    then
        echo ""
        echo "Which option are you using to register the system? : "
        rhsm_msg=("Activation Key" "Username and Password")
        createmenu "${rhsm_msg[@]}"
        rhsm_reg_method=($(echo "${selected_option}"))
        sed -i "s/rhsm_reg_method: \"\"/rhsm_reg_method: "$rhsm_reg_method"/g" "${vars_file}"
        if [ "A${rhsm_reg_method}" == "AUsername" ];
        then
            echo ""
            decrypt_ansible_vault "${vault_vars_file}"
            get_rhsm_user_and_pass
            encrypt_ansible_vault "${vault_vars_file}"
        elif [ "A${rhsm_reg_method}" == "AActivation" ];
        then
            if grep '""' "${vault_vars_file}"|grep -q rhsm_username
            then
                echo ""
                echo "We still need to get your RHSM username and password."
                echo "We need this to pull containers for OpenShift Platform Installation."
                echo ""
                decrypt_ansible_vault "${vault_vars_file}"
                get_rhsm_user_and_pass
                encrypt_ansible_vault "${vault_vars_file}"
                echo ""
            fi

            if grep '""' "${vault_vars_file}"|grep -q rhsm_activationkey
            then
                echo -n "Enter your RHSM activation key and press [ENTER]: "
                read rhsm_activationkey
                unset rhsm_org
                sed -i "s/rhsm_activationkey: \"\"/rhsm_activationkey: "$rhsm_activationkey"/g" "${vaultfile}"
            fi
            if grep '""' "${vault_vars_file}"|grep -q rhsm_org
            then
                echo -n 'Enter your RHSM ORG ID and press [ENTER]: '
                read_sensitive_data
                rhsm_org="${sensitive_data}"
                sed -i "s/rhsm_org: \"\"/rhsm_org: "$rhsm_org"/g" "${vaultfile}"
                echo ""
            fi
        fi
    elif grep '""' "${vaultfile}"|grep -q rhsm_username
    then
        echo ""
        decrypt_ansible_vault "${vault_vars_file}"
        get_rhsm_user_and_pass
        encrypt_ansible_vault "${vault_vars_file}"
    else
        echo "Credentials for RHSM is already collected."
    fi

    # encrypt ansible vault
    encrypt_ansible_vault "${vaultfile}"
}

function prereqs () {
    # setup required paths
    setup_required_paths
    #
    # set subscription pool dsetup MAIN variables
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
    DEFAULT_INTERFACE=$(ip route list | awk '/^default/ {print $5}')
    NETMASK_PREFIX=$(ip -o -f inet addr show $DEFAULT_INTERFACE | awk '{print $4}'|cut -d'/' -f2)
}

function setup_sudoers () {
    prereqs
    echo "Checking if ${CURRENT_USER} is setup for password-less sudo: "
    elevate_cmd test -f "/etc/sudoers.d/${CURRENT_USER}"
    if [ "A$?" != "A0" ]
    then
        SUDOERS_TMP=$(mktemp)
        echo "Setting up /etc/sudoers.d/${CURRENT_USER}"
	echo "${CURRENT_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_TMP}"
        elevate_cmd cp "${SUDOERS_TMP}" "/etc/sudoers.d/${CURRENT_USER}"
        sudo chmod 0440 "/etc/sudoers.d/${CURRENT_USER}"
    else
        echo "${CURRENT_USER} is setup for password-less sudo"
    fi
}

function setup_user_ssh_key () {
    HOMEDIR=$(eval echo ~${CURRENT_USER})
    if [ ! -f "${HOMEDIR}/.ssh/id_rsa.pub" ]
    then
        echo "Setting up ssh keys for ${CURRENT_USER}"
        ssh-keygen -f "${HOMEDIR}/.ssh/id_rsa" -q -N ''
    fi
}

function setup_variables () {
    prereqs
    # copy sample vars file to playbook/vars directory
    if [ ! -f "${vars_file}" ]
    then
      cp "${project_dir}/samples/all.yml" "${vars_file}"
    fi

    # create vault vars file
    if [ ! -f "${vault_vars_file}" ]
    then
        cp "${project_dir}/samples/vault.yml" "${vault_vars_file}"
    fi

    # create ansible inventory file
    if [ ! -f "${hosts_inventory_dir}/hosts" ]
    then
        cp "${project_dir}/samples/hosts" "${hosts_inventory_dir}/hosts"
    fi

    echo ""
    echo "Populating ${vars_file}"
    # add inventory file to all.yml
    if grep '""' "${vars_file}"|grep -q inventory_dir
    then
        echo "Adding inventory_dir variable"
        sed -i "s#inventory_dir: \"\"#inventory_dir: "$hosts_inventory_dir"#g" "${vars_file}"
    fi

    # Set KVM project dir
    if grep '""' "${vars_file}"|grep -q project_dir
    then
        echo "Adding project_dir variable"
        sed -i "s#project_dir: \"\"#project_dir: "$project_dir"#g" "${vars_file}"
    fi

    # Set KVM host ip info
    if grep '""' "${vars_file}"|grep -q kvm_host_ip
    then
        echo "Adding kvm_host_ip variable"
        sed -i "s#kvm_host_ip: \"\"#kvm_host_ip: "$IPADDR"#g" "${vars_file}"
    fi

    if grep '""' "${vars_file}"|grep -q kvm_host_gw
    then
        echo "Adding kvm_host_gw variable"
        sed -i "s#kvm_host_gw: \"\"#kvm_host_gw: "$GTWAY"#g" "${vars_file}"
    fi

    if grep '""' "${vars_file}"|grep -q kvm_host_mask_prefix
    then
        echo "Adding kvm_host_mask_prefix variable"
        sed -i "s#kvm_host_mask_prefix: \"\"#kvm_host_mask_prefix: "$NETMASK_PREFIX"#g" "${vars_file}"
    fi

    if grep '""' "${vars_file}"|grep -q kvm_host_interface
    then
        echo "Adding kvm_host_interface variable"
        sed -i "s#kvm_host_interface: \"\"#kvm_host_interface: "$DEFAULT_INTERFACE"#g" "${vars_file}"
    fi
    echo ""
}

function ask_user_input () {
    echo ""
    echo ""
    ask_for_values "${vars_file}"
    ask_for_vault_values "${vault_vars_file}"
}

function check_for_rhel_qcow_image () {
    # check for required OS qcow image and copy it to right location
    libvirt_dir=$(awk '/^kvm_host_libvirt_dir/ {print $2}' "${project_dir}/samples/all.yml")
    os_qcow_image=$(awk '/^os_qcow_image_name/ {print $2}' "${project_dir}/samples/all.yml")
    if [ ! -f "${libvirt_dir}/${os_qcow_image}" ]
    then
        if [ -f "${project_dir}/${os_qcow_image}" ]
        then
            sudo cp "${project_dir}/${os_qcow_image}" "${libvirt_dir}/${os_qcow_image}"
        else
            echo "Could not find ${project_dir}/${os_qcow_image}, please download the ${os_qcow_image} to ${project_dir}."
            echo "Please refer the documentation for additional information."
            exit 1
        fi
    else
        echo "The require OS image ${libvirt_dir}/${os_qcow_image} was found."
    fi
}

function qubinode_installer_preflight () {
    prereqs
    setup_sudoers
    setup_user_ssh_key
    setup_variables
    ask_user_input

    # Setup admin user variable
    if grep '""' "${vars_file}"|grep -q admin_user
    then
        echo "Updating ${vars_file} admin_user variable"
        sed -i "s#admin_user: \"\"#admin_user: "$CURRENT_USER"#g" "${vars_file}"
    fi
  
    # Pull variables from all.yml needed for the install
    domain=$(awk '/^domain:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
}

function qubinode_setup_kvm_host () {
    prereqs
    # check for host inventory file
    if [ ! -f "${hosts_inventory_dir}/hosts" ]
    then
        echo "Inventory file ${hosts_inventory_dir}/hosts is missing"
        echo "Please run qubinode-installer -m setup"
        echo ""
        exit 1
    fi

    # check for inventory directory
    if [ -f "${vars_file}" ]
    then
        if grep '""' "${vars_file}"|grep -q inventory_dir
        then
            echo "No value set for inventory_dir in ${vars_file}"
            echo "Please run qubinode-installer -m setup"
            echo ""
            exit 1
        fi
     else
        echo "${vars_file} is missing"
        echo "Please run qubinode-installer -m setup"
        echo ""
        exit 1
     fi

    # Check for ansible and ansible role
    ROLE_PRESENT=$(ansible-galaxy list | grep 'swygue.edge_host_setup')
    if [ ! -f /usr/bin/ansible ]
    then
        echo "Ansible is not installed"
        echo "Please run qubinode-installer -m ansible"
        echo ""
        exit 1
    elif [ "A${ROLE_PRESENT}" == "A" ]
    then
        echo "Required role swygue.edge_host_setup is missing."
        echo "Please run run qubinode-installer -m ansible"
        echo ""
        exit 1
    fi

    # future check for pool id
    #if grep '""' "${vars_file}"|grep -q openshift_pool_id
    #then
    ansible-playbook "${project_dir}/playbooks/setup_kvmhost.yml" || exit $?
}


function qubinode_project_cleanup () {
    prereqs
    FILES=()
    mapfile -t FILES < <(find "${project_dir}/inventory/" -not -path '*/\.*' -type f)
    if [ -f "$vault_vars_file" ] && [ -f "$vault_vars_file" ]
    then
        FILES=("${FILES[@]}" "$vault_vars_file" "$vars_file")
    fi

    if [ ${#FILES[@]} -eq 0 ]
    then
        echo "Project directory: ${project_dir} state is already clean"
    else
        for f in $(echo "${FILES[@]}")
        do
            test -f $f && rm $f
            echo "purged $f"

        done
    fi
}


function confirm () {
    continue=""
    while [[ "${continue}" != "yes" ]];
    do
        read -r -p "${1:-Are you sure Yes or no?} " response
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
        then
            echo "You chose yes"
            response="yes"
            continue="yes"
        elif [[ $response =~ ^([nN][oO])$ ]]
        then
            echo "You chose no"
            response="no"
            continue="yes"
        else
            echo "Try again"
        fi
    done
}

function verbose() {
    if [[ $_V -eq 1 ]]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

function default_install () {
    product_opt="ocp"
    product=true
    printf "\n\n***********************\n"
    printf "* Running perquisites *\n"
    printf "***********************\n\n"
    qubinode_installer_preflight 

    printf "\n\n********************************************\n"
    printf "* Ensure host system is registered to RHSM *\n"
    printf "*********************************************\n\n"
    qubinode_rhsm_register
    
    printf "\n\n*******************************************************\n"
    printf "* Ensure host system is setup as a ansible controller *\n"
    printf "*******************************************************\n\n"
    qubinode_setup_ansible

    printf "\n\n*********************************************\n"
    printf     "* Ensure host system is setup as a KVM host *\n"
    printf     "*********************************************\n"
    qubinode_setup_kvm_host

    printf "\n\n****************************\n"
    printf     "* Deploy VM for DNS server *\n"
    printf     "****************************\n"
    qubinode_vm_manager deploy_dns
    
    printf "\n\n*****************************\n"
    printf     "* Install IDM on DNS server *\n"
    printf     "*****************************\n"
    qubinode_dns_manager server

    printf "\n\n******************************\n"
    printf     "* Deploy DNS for ${product_opt} cluster *\n"
    printf     "******************************\n"
    qubinode_vm_manager deploy_nodes

    printf "\n\n*********************\n"
    printf     "*Deploy ${product_opt} cluster *\n"
    printf     "*********************\n"
    qubinode_deploy_openshift

    printf "\n\n*******************************************************\n"
    printf   "\nDeployment steps for ${product_opt} cluster is complete.\n"
    printf "\nCluster login: https://ocp-master01.${domain}:8443\n"
    printf "     Username: changeme\n"
    printf "     Password: <yourpassword>\n"
    printf "\n\nIDM DNS Server login: https://ocp-dns01.${domain}\n"
    printf "     Username: admin\n"
    printf "     Password: <yourpassword>\n"
    printf "*******************************************************\n"
}
