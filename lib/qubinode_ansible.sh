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

    if [[ $RHEL_VERSION == "RHEL8" ]]; then
        AVAILABLE_VERSION=$(sudo dnf --showduplicates list ansible | awk -v r1=$ANSIBLE_RELEASE '$0 ~ r1 {print $2}' | tail -1)
    elif [[ $RHEL_VERSION == "RHEL7" ]]; then
        AVAILABLE_VERSION=$(sudo yum --showduplicates list ansible | awk -v r1=$ANSIBLE_RELEASE '$0 ~ r1 {print $2}' | tail -1)
    fi

    if [ "A${ANSIBLE_VERSION_GOOD}" != "AYES" ]
    then
        if [ "A${AVAILABLE_VERSION}" != "A" ]
        then
            if [[ $RHEL_VERSION == "RHEL8" ]]; then
                sudo dnf install "ansible-${AVAILABLE_VERSION}" -y
            elif [[ $RHEL_VERSION == "RHEL7" ]]; then
                sudo yum install "ansible-${AVAILABLE_VERSION}" -y
            fi
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
    RHEL_VERSION=$(awk '/rhel_version/ {print $2}' "${vars_file}")

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
    if [[ $RHEL_VERSION == "RHEL8" ]]
    then
        if [ ! -f /usr/bin/python3 ]
        then
            sudo subscription-manager repos --enable="rhel-8-for-x86_64-baseos-rpms" > /dev/null 2>&1
            sudo subscription-manager repos --enable="rhel-8-for-x86_64-appstream-rpms" > /dev/null 2>&1
            printf "%s\n" "   ${yel}Installing required python rpms..${end}"
            sudo dnf clean all > /dev/null 2>&1
            sudo rm -r /var/cache/dnf
            sudo yum install -y -q -e 0 python3 python3-pip python3-dns > /dev/null 2>&1
	    sed -i "s/ansible_python_interpreter:.*/ansible_python_interpreter: /usr/bin/python3/g" "${vars_file}"
	fi
    elif [[ $RHEL_VERSION == "RHEL7" ]]; then
        if [ ! -f /usr/bin/python ]
        then
            printf "%s\n" "   ${yel}Installing required python rpms..${end}"
            sudo yum clean all > /dev/null 2>&1
            sudo yum install -y -q -e 0 python python3-pip python2-pip python-dns
	    #sed -i "s/ansible_python_interpreter:.*/ansible_python_interpreter: /usr/bin/python/g" "${vars_file}"
        fi
    else
       PYTHON=yes
    fi

    # Update system
    printf "%s\n" "   ${yel}Updating system...${end}"
    sudo yum update -y --allowerasing > /dev/null 2>&1

    # install ansible
    if [ ! -f /usr/bin/ansible ];
    then
      if [[ $RHEL_VERSION == "RHEL8" ]]; then
        ANSIBLE_REPO=$(awk '/rhel8_ansible_repo:/ {print $2}' "${vars_file}")
      elif [[ $RHEL_VERSION == "RHEL7" ]]; then
        ANSIBLE_REPO=$(awk '/rhel7_ansible_repo:/ {print $2}' "${vars_file}")
      fi
       CURRENT_REPO=$(sudo subscription-manager repos --list-enabled| awk '/ID:/ {print $3}'|grep ansible)
       # check to make sure the support ansible repo is enabled
       if [ "A${CURRENT_REPO}" != "A${ANSIBLE_REPO}" ]
       then
           sudo subscription-manager repos --disable="${CURRENT_REPO}"
           sudo subscription-manager repos --enable="${ANSIBLE_REPO}"
       fi
       if [[ $RHEL_VERSION == "RHEL8" ]]; then
            sudo dnf clean all > /dev/null 2>&1
            sudo dnf install -y -q -e 0 ansible git
        elif [[ $RHEL_VERSION == "RHEL7" ]]; then
            sudo yum clean all > /dev/null 2>&1
            sudo yum install -y -q -e 0 ansible git
        fi
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
        if ! ansible-vault view "${vaultfile}" >/dev/null 2>&1
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
            wget https://raw.githubusercontent.com/jfenal/ansible-modules-jfenal/ctrlplane/packaging/os/redhat_repositories.py
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
