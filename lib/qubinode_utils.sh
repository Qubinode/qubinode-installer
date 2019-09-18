#!/bin/bash

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

function check_for_hash () {
    if [ -n $string ] && [ `expr "$string" : '[0-9a-fA-F]\{32\}\|[0-9a-fA-F]\{40\}'` -eq ${#string} ]
    then
        echo "valid"
    else
        echo "invalid"
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

function prereqs () {
    # setup required paths
    setup_required_paths
    CURRENT_USER=$(whoami)
    vault_key_file="/home/${CURRENT_USER}/.vaultkey"
    vault_vars_file="${project_dir}/playbooks/vars/vault.yml"
    vars_file="${project_dir}/playbooks/vars/all.yml"
    hosts_inventory_dir="${project_dir}/inventory"
    inventory_file="${hosts_inventory_dir}/hosts"
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

    # Setup admin user variable
    if grep '""' "${vars_file}"|grep -q admin_user
    then
        echo "Updating ${vars_file} admin_user variable"
        sed -i "s#admin_user: \"\"#admin_user: "$CURRENT_USER"#g" "${vars_file}"
    fi

    # Pull variables from all.yml needed for the install
    domain=$(awk '/^domain:/ {print $2}' "${vars_file}")
    echo ""

    # Check if we should setup qubinode
    QUBINODE_SYSTEM=$(awk '/run_qubinode_setup/ {print $2; exit}' "${vars_file}" | tr -d '"')

    # Check if we should setup qubinode
    DNS_SERVER_NAME=$(awk -F'-' '/idm_hostname:/ {print $2; exit}' "${vars_file}" | tr -d '"')

    # Satellite server vars file
    SATELLITE_VARS_FILE="${project_dir}/playbooks/vars/satellite_server.yml"

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
            response="yes"
            continue="yes"
        elif [[ $response =~ ^([nN][oO])$ ]]
        then
            echo "You choose $response"
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

function contains_string () {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && echo "$2" || echo 'invalid'
}


function isRPMinstalled() {
    if rpm -q $1 &> /dev/null; then
        return 0
    else
        return 1
    fi
}
