#!/bin/bash


function qubinode_project_cleanup () {
    # resets the project to a clean state by removing all vars files
    # ensure requirements are in place
    qubinode_required_prereqs

    FILES=()
    mapfile -t FILES < <(find "${project_dir}/inventory/" -not -path '*/\.*' -type f)
    if [ -f "$vault_vars_file" ] && [ -f "$vault_vars_file" ]
    then
        FILES=("${FILES[@]}" "$vault_vars_file" "$vars_file")
    fi

    # Delete OpenShift 3 files
    if [ -f ${project_dir}/playbooks/vars/ocp3.yml ]
    then 
        openshift_product=$(awk '/^product:/ {print $2}' "${project_dir}/playbooks/vars/ocp3.yml")
        if [[ ${openshift_product} == "ocp3" ]]; then
          FILES=("${FILES[@]}" "$ocp3_vars_files")
        elif [[ ${openshift_product} == "okd3" ]]; then
          FILES=("${FILES[@]}" "$okd3_vars_files")
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
    fi

   echo "Removing playbook vars"
   rm -rvf ${project_dir}/playbooks/vars/*.yml > /dev/null
   echo "Removing downloaded roles"
   rm -rvf ${project_dir}/playbooks/roles/* > /dev/null
}

function cleanStaleKnownHost () {
    user=$1
    host=$2
    alt_host_name=$3
    isKnownHostStale=$(ssh -o connecttimeout=2 -o stricthostkeychecking=no ${user}@${host} true 2>&1|grep -c "Offending")
    if [ "A${isKnownHostStale}" == "A1" ]
    then
        ssh-keygen -R ${host} >/dev/null 2>&1
        if [ "A${alt_host_name}" != "A" ]
        then
            ssh-keygen -R ${alt_host_name} >/dev/null 2>&1
        fi
    fi
}

function canSSH () {
    user=$1
    host=$2
    RESULT=$(ssh -q -o StrictHostKeyChecking=no -o "BatchMode=yes" -i /home/${user}/.ssh/id_rsa "${user}@${host}" "echo 2>&1" && echo SSH_OK || echo SSH_NOK)
    echo $RESULT
}



function get_admin_user_password () {
    echo " Fetching the Admin user password."
    decrypt_ansible_vault "${vault_vars_file}" > /dev/null
    admin_user_passowrd=$(awk '/admin_user_password:/ {print $2}' "${vault_vars_file}")
    encrypt_ansible_vault "${vaultfile}" >/dev/null
    if [ "A${admin_user_passowrd}" == "A" ]
    then
        print "%s\n" " Unable to retrieve ${yel}$CURRENT_USER${end} user password from the vault"
        exit 1
    fi
}

function exit_status () {
    RESULT=$?
    FAIL_MSG=$1
    LINE=$2
    if [ "A${RESULT}" != "A0" ]
    then
        echo "LINE $LINE - FAILED TO COMPLETE: ${FAIL_MSG}"
        exit "${RESULT}"
    fi
}


convertB_human() {
    # Thanks to https://bit.ly/39xomtN
    NUMBER=$1
    for DESIG in Bytes KB MB GB TB PB
    do
        [ $NUMBER -lt 1024 ] && break
        let NUMBER=$NUMBER/1024
    done

    DISK_SIZE_HUMAN=$(printf "%d %s\n" $NUMBER $DESIG)
    DISK_SIZE_COMPARE=$(printf "%d %s\n" $NUMBER)
}

function isvmRunning () {
    sudo virsh list |grep $vm|awk '/running/ {print $2}'
}

function isvmShutdown () {
    sudo virsh list --all | grep $vm| awk '/shut/ {print $2}'
}

