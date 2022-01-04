#!/bin/bash

# this function make sure Ansible is installed
# along with any other dependancy the project
# depends on

function ensure_supported_ansible_version () {
    ANSIBLE_VERSION=$(awk '/ansible_version/ {print $2}' "${vars_file}")
    ANSIBLE_RELEASE=$(awk '/ansible_release/ {print $2}' "${vars_file}")
    ANSIBLE_RPM=$(awk '/ansible_rpm/ {print $2}' "${vars_file}")
    CURRENT_ANSIBLE_VERSION=$(ansible --version | awk '/^ansible/ {print $2}')
    ANSIBLE_VERSION_GOOD=$(awk -vv1="$ANSIBLE_VERSION" -vv2="$CURRENT_ANSIBLE_VERSION" 'BEGIN { print (v2 >= v1) ? "YES" : "NO" }')
    ANSIBLE_VERSION_GREATER=$(awk -vv1="$ANSIBLE_VERSION" -vv2="$CURRENT_ANSIBLE_VERSION" 'BEGIN { print (v2 > v1) ? "YES" : "NO" }')
    RHEL_VERSION=$(awk '/rhel_version/ {print $2}' "${vars_file}")

    # Get the ansible version
    if [ "${RHEL_VERSION:-none}" == "RHEL8" ]
    then
        AVAILABLE_VERSION=$(sudo dnf --showduplicates list ansible | awk -v r1=$ANSIBLE_RELEASE '$0 ~ r1 {print $2}' | tail -1)
    elif [ "${RHEL_VERSION:-none}" == "RHEL7" ]
    then
        AVAILABLE_VERSION=$(sudo yum --showduplicates list ansible | awk -v r1=$ANSIBLE_RELEASE '$0 ~ r1 {print $2}' | tail -1)
    fi

    if [ "${ANSIBLE_VERSION_GOOD:-none}" != "YES" ]
    then
        if [ "${AVAILABLE_VERSION:-none}" != "none" ]
        then
            # Update ansible
            printf "%s\n" "   ${mag}Updating ansible ${end}"
            sudo yum update -y --allowerasing ansible > /dev/null 2>&1
        else
            printf "%s\n" ""
            printf "%s\n" " ${cyn}**WARNING**${end}"
            printf "%s\n" " Your ansible version $CURRENT_ANSIBLE_VERSION is older than the tested version of $ANSIBLE_VERSION"
        fi
    fi

}

function qubinode_ansible_requirements_file_check () {
    if $(which git >/dev/null 2>&1 && git symbolic-ref HEAD >/dev/null 2>&1)
    then
        local branch
	      branch=$(git symbolic-ref HEAD 2>/dev/null| sed -e 's,.*/\(.*\),\1,')

	    if [[ "${branch:-none}" != "master" ]] || [[ "${branch:-none}" != "main" ]]
	    then
            if [ ! -f "${project_dir}/playbooks/requirements-${branch}.yml" ]
            then
                printf "%s\n" "     You appear to be developing for the qubinode-installer and you do not"
                printf "%s\n" "     have a copy of the requirements-dev to match the branch ${blu}$branch${end} you are"
                printf "%s\n\n\n" "     developing on."
                confirm "     Do you want to use the ${blu}requirements-dev.yml${end} with your ${blu}$branch${end}? yes/no"
                if [ "${response:-none}" == "yes" ]
                then
	                  ANSIBLE_DEV_REQ_FILE="${project_dir}/playbooks/requirements-${branch}.yml"
                    printf "%s\n" "     Copying ${blu}requirements-dev.yml${end} to ${blu}requirements-${branch}.yml${end}"
                    printf "%s\n\n" "     Don't forget to merge ${blu}requirements-${branch}.yml${end} with ${blu}requirements-dev.yml${end}"
                    cp "${project_dir}/playbooks/requirements-dev.yml" "${ANSIBLE_DEV_REQ_FILE}"

                    #printf "%s\n" "     Reverting changes that may have been made to requirements.yml or requirements-dev.yml"
                    #git reset HEAD $DEFAULT_ANSIBLE_REQUIREMENTS_FILE >/dev/null 2>&1
                fi
            fi

	    fi
    fi    
}
function qubinode_setup_ansible () {
    qubinode_required_prereqs
    vaultfile="${vault_vars_file}"
    RHEL_VERSION=$(awk '/rhel_version/ {print $2}' "${vars_file}")
    ANSIBLE_REQUIREMENTS_FILE="${project_dir}/playbooks/requirements.yml"
    
    if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
    then
        check_rhsm_status
    fi

    #Get required ansible repo
    if [ "${RHEL_VERSION:-none}" == "RHEL8" ]
    then
        ANSIBLE_REPO=$(awk '/rhel8_ansible_repo:/ {print $2}' "${vars_file}")
    elif [ "${RHEL_VERSION:-none}" == "RHEL7" ]
    then
        ANSIBLE_REPO=$(awk '/rhel7_ansible_repo:/ {print $2}' "${vars_file}")
    fi    

    # install python
    if [[ $RHEL_VERSION == "RHEL8" ]]
    then
        if [ ! -f /usr/bin/python3 ]
        then
            sudo subscription-manager repos --enable="rhel-8-for-x86_64-baseos-rpms" > /dev/null 2>&1
            sudo subscription-manager repos --enable="rhel-8-for-x86_64-appstream-rpms" > /dev/null 2>&1
            printf "%s\n" "   ${yel}Installing required python rpms..${end}"
            sudo dnf clean all > /dev/null 2>&1
            sudo rm -r /var/cache/dnf
            sudo yum install -y -q -e 0 python3 python3-pip python3-dns bc bind-utils> /dev/null 2>&1
	        sed -i "s/ansible_python_interpreter:.*/ansible_python_interpreter: /usr/bin/python3/g" "${vars_file}"
	    fi
    elif [[ $RHEL_VERSION == "RHEL7" ]]; then
        if [ ! -f /usr/bin/python ]
        then
            printf "%s\n" "   ${yel}Installing required python rpms..${end}"
            sudo yum clean all > /dev/null 2>&1
            sudo yum install -y -q -e 0 python python3-pip python2-pip python-dns  bc bind-utils
        fi
    else
       PYTHON=yes
    fi

    # install ansible
    if [ ! -f /usr/bin/ansible ];
    then
       CURRENT_REPO=$(sudo subscription-manager repos --list-enabled| awk '/ID:/ {print $3}'|grep ansible)
       # check to make sure the support ansible repo is enabled
       if [ "A${CURRENT_REPO}" != "A${ANSIBLE_REPO}" ]
       then
           sudo subscription-manager repos --disable="${CURRENT_REPO}"
           sudo subscription-manager repos --enable="${ANSIBLE_REPO}"
           sudo yum clean all > /dev/null 2>&1
           sudo yum install -y -q -e 0 ansible git  bc bind-utils
        fi    
    fi

    # Verify ansible version
    ensure_supported_ansible_version

    # setup vault
    if [ -f /usr/bin/ansible ];
    then
        if [ ! -f "${vault_key_file}" ]
        then
            printf "%s\n" " Create ansible-vault password file ${vault_key_file}"
            openssl rand -base64 512|xargs > "${vault_key_file}"
        fi

        #if cat "${vaultfile}" | grep -q VAULT
        if ! ansible-vault view "${vaultfile}" >/dev/null 2>&1
        then
            #printf "%s\n" " Encrypting ${vaultfile}"
            ansible-vault encrypt "${vaultfile}" > /dev/null 2>&1
        fi

	    # Check if development and which requirements file to use
        qubinode_ansible_requirements_file_check
        if [ "${ANSIBLE_DEV_REQ_FILE:-none}" != "none" ]
        then
            ANSIBLE_REQUIREMENTS_FILE="${ANSIBLE_DEV_REQ_FILE}"
        fi

        # Ensure roles are downloaded
        if [ "${qubinode_maintenance_opt}" == "ansible" ]
        then
	    printf "%s\n" "   ${mag}Downloading required roles overwriting existing${end}"
            ansible-galaxy install --force -r "${ANSIBLE_REQUIREMENTS_FILE}" > /dev/null 2>&1 || exit $?
        else
            printf "%s\n" " ${mag}Downloading required roles${end}"
            ansible-galaxy install -r "${ANSIBLE_REQUIREMENTS_FILE}" > /dev/null 2>&1 || exit $?
        fi

        # Ensure required modules are downloaded
        if [ ! -f "${project_dir}/playbooks/modules/redhat_repositories.py" ]
        then
            test -d "${project_dir}/playbooks/modules" || mkdir "${project_dir}/playbooks/modules"
            CURRENT_DIR=$(pwd)
            cd "${project_dir}/playbooks/modules/"
            wget https://raw.githubusercontent.com/jfenal/ansible-modules-jfenal/ctrlplane/packaging/os/redhat_repositories.py
            cd "${CURRENT_DIR}"
        fi
    else
        printf "%s\n" " Ansible not found, please install and retry."
        exit 1
    fi

    sed -i "s/qubinode_installer_ansible_completed:.*/qubinode_installer_ansible_completed: yes/g" "${vars_file}"
    printf "${yel}    Ansible Setup Complete ${end}\n"

}

function decrypt_ansible_vault () {
    vaultfile="${project_dir}/playbooks/vars/vault.yml"
    grep -q VAULT "${vault_vars_file}"
    if [ "A$?" == "A0" ]
    then
        cd "${project_dir}/"
        test -f /usr/bin/ansible-vault && ansible-vault decrypt "${vaultfile}"
        ansible_encrypt=yes
    fi
}

function encrypt_ansible_vault () {
    vaultfile="${project_dir}/playbooks/vars/vault.yml"
    grep -q VAULT "${vaultfile}"
    if [ "A$?" != "A0" ]
    then
        cd "${project_dir}/"
        test -f /usr/bin/ansible-vault && ansible-vault encrypt "${vaultfile}"
    fi
}
