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
    AVAILABLE_VERSION=$(sudo yum --showduplicates list ansible | awk -v r1=$ANSIBLE_RELEASE '$0 ~ r1 {print $2}' | tail -1)

    if [ "A${ANSIBLE_VERSION_GOOD}" != "AYES" ]
    then
        if [ "A${AVAILABLE_VERSION}" != "A" ]
        then
            sudo yum install "ansible-${AVAILABLE_VERSION}" -y
        else
            printf "%s\n" " Could not find any available version of ansible greater than the"
            printf "%s\n" " current installed version $CURRENT_ANSIBLE_VERSION"
            exit 1
        fi
    fi

    if [ "A${ANSIBLE_VERSION_GOOD}" != "AYES" ]
    then
        printf "%s\n" ""
        printf "%s\n" " ${cyn}**WARNING**${end}"
        printf "%s\n" " Your ansible version $CURRENT_ANSIBLE_VERSION is later than the tested version of $ANSIBLE_VERSION"
    fi
}


function qubinode_setup_ansible () {
    qubinode_required_prereqs
    vaultfile="${vault_vars_file}"
    HAS_SUDO=$(has_sudo)
    if [ "A${HAS_SUDO}" == "Ano_sudo" ]
    then
        printf "%s\n" " ${red}You do not have sudo access${end}"
        printf "%s\n" " Please run ${grn}qubinode-installer -m setup${end}"
        exit 1
    fi

    if [ "A${QUBINODE_SYSTEM}" == "Ayes" ]
    then
        check_rhsm_status
    fi

    # install python
    if [ ! -f /usr/bin/python ];
    then
       printf "%s\n" " Installing python.."
       sudo yum clean all > /dev/null 2>&1
       sudo yum install -y -q -e 0 python python3-pip python2-pip python-dns
    else
       PYTHON=yes
       #printf "%s\n" " python is installed"
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
       ensure_supported_ansible_version
    else
       ensure_supported_ansible_version
       #printf "%s\n" " ${cyn}Ansible is installed${end}"
    fi

    # setup vault
    if [ -f /usr/bin/ansible ];
    then
        if [ ! -f "${vault_key_file}" ]
        then
            printf "%s\n" " Create ansible-vault password file ${vault_key_file}"
            openssl rand -base64 512|xargs > "${vault_key_file}"
        fi

        #if cat "${vaultfile}" | grep -q VAULT
        if ! ansible-vault view "${vaultfile}" > /dev/null
        then
            #printf "%s\n" " Encrypting ${vaultfile}"
            ansible-vault encrypt "${vaultfile}" > /dev/null 2>&1
        fi

        # Ensure roles are downloaded
        if [ "${qubinode_maintenance_opt}" == "ansible" ]
        then
            printf "%s\n" " Downloading required roles overwriting existing"
            ansible-galaxy install --force -r "${project_dir}/playbooks/requirements.yml" || exit $?
        else
            printf "%s\n" " Downloading required roles"
            ansible-galaxy install -r "${project_dir}/playbooks/requirements.yml" > /dev/null 2>&1
        fi

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
        printf "%s\n" " Ansible not found, please install and retry."
        exit 1
    fi

    sed -i "s/qubinode_installer_ansible_completed:.*/qubinode_installer_ansible_completed: yes/g" "${vars_file}"
    printf "\n\n${yel}    *******************************${end}\n"
    printf "${yel}    *   Ansible Setup Complete   *${end}\n"
    printf "${yel}    *******************************${end}\n\n"

}

function decrypt_ansible_vault () {
    vaulted_file="$1"
    grep -q VAULT "${vaulted_file}"
    if [ "A$?" == "A0" ]
    then
        cd "${project_dir}/"
        test -f /usr/bin/ansible-vault && ansible-vault decrypt "${vaulted_file}"
        ansible_encrypt=yes
    fi
}

function encrypt_ansible_vault () {
    vaulted_file="$1"
    if [ "A${ansible_encrypt}" == "Ayes" ]
    then
        cd "${project_dir}/"
        test -f /usr/bin/ansible-vault && ansible-vault encrypt "${vaulted_file}"
    fi
}
