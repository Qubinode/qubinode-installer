#!/bin/bash

# this function make sure Ansible is installed
# along with any other dependancy the project
# depends on
function qubinode_setup_ansible () {
    qubinode_required_prereqs
    vaultfile="${vault_vars_file}"
    HAS_SUDO=$(has_sudo)
    if [ "A${HAS_SUDO}" == "Ano_sudo" ]
    then
        echo "You do not have sudo access"
        echo "Please run qubinode-installer -m setup"
        exit 1
    fi

    if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
    then
        check_rhsm_status
    fi

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
        if [ "${qubinode_maintenance_opt}" == "ansible" ]
        then
            ansible-galaxy install --force -r "${project_dir}/playbooks/requirements.yml" || exit $?
        else
            ansible-galaxy install -r "${project_dir}/playbooks/requirements.yml" > /dev/null 2>&1
        fi
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

    printf "\n\n***************************\n"
    printf "* Ansible Setup Complete *\n"
    printf "***************************\n\n"
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
