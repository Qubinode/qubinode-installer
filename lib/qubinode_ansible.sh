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
    RHEL_VERSION=$(get_rhel_version)
    RUN_KNI_ON_RHPDS=$(awk '/run_kni_lab_on_rhpds/ {print $2}' "${vars_file}")
    vault_vars_file="${project_dir}/playbooks/vars/vault.yml"

    if [[ $RHEL_VERSION == "RHEL9" ]]; then
        AVAILABLE_VERSION=$(sudo dnf --showduplicates list ansible | awk -v r1=$ANSIBLE_RELEASE '$0 ~ r1 {print $2}' | tail -1)
    elif [[ $RHEL_VERSION == "RHEL8" ]]; then
        if [ ${RUN_KNI_ON_RHPDS} == "no" ]
        then
            AVAILABLE_VERSION=$(sudo dnf --showduplicates list ansible | awk -v r1=$ANSIBLE_RELEASE '$0 ~ r1 {print $2}' | tail -1)
        fi
    elif [[ $RHEL_VERSION == "RHEL7" ]]; then
        AVAILABLE_VERSION=$(sudo yum --showduplicates list ansible | awk -v r1=$ANSIBLE_RELEASE '$0 ~ r1 {print $2}' | tail -1)
    fi

    if [ "A${ANSIBLE_VERSION_GOOD}" != "AYES" ]
    then
        if [ "A${AVAILABLE_VERSION}" != "A" ]
        then
            if [[ $RHEL_VERSION == "RHEL9" ]]; then
                sudo dnf install "ansible-${AVAILABLE_VERSION}" -y
            elif [[ $RHEL_VERSION == "RHEL8" ]]; then
                if [ ${RUN_KNI_ON_RHPDS} == "no" ]
                then
                    sudo dnf install "ansible-${AVAILABLE_VERSION}" -y
                fi 
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
    RHEL_VERSION=$(get_rhel_version)

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
    if [[ $RHEL_VERSION == "RHEL9" ]]
    then
        if [ ! -f /usr/bin/python3 ]
        then
            sudo subscription-manager repos --enable="rhel-9-for-x86_64-baseos-rpms" > /dev/null 2>&1
            sudo subscription-manager repos --enable="rhel-9-for-x86_64-appstream-rpms" > /dev/null 2>&1
            printf "%s\n" "   ${yel}Installing required python rpms..${end}"
            sudo dnf clean all > /dev/null 2>&1
            sudo rm -r /var/cache/dnf
            sudo yum install -y -q -e 0 python3 python3-pip python3-dns bc bind-utils> /dev/null 2>&1
	    sed -i "s/ansible_python_interpreter:.*/ansible_python_interpreter: /usr/bin/python3/g" "${vars_file}"
	fi
    elif [[ $RHEL_VERSION == "RHEL8" ]]
    then
        if [ ! -f /usr/bin/python3 ]
        then
            if [ ${RUN_KNI_ON_RHPDS} == "no" ]
            then
                sudo subscription-manager repos --enable="rhel-8-for-x86_64-baseos-rpms" > /dev/null 2>&1
                sudo subscription-manager repos --enable="rhel-8-for-x86_64-appstream-rpms" > /dev/null 2>&1
            fi
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
	    #sed -i "s/ansible_python_interpreter:.*/ansible_python_interpreter: /usr/bin/python/g" "${vars_file}"
        fi
    else
       PYTHON=yes
    fi



    # install ansible
    if [ ! -f /tmp/ansible_install.log ];
    then
        if [[ $RHEL_VERSION == "RHEL9" ]]; then
            echo "Installing ansible.."
        if [[ $RHEL_VERSION == "RHEL8" ]]; then
            ANSIBLE_REPO=$(awk '/rhel8_ansible_repo:/ {print $2}' "${vars_file}")
        elif [[ $RHEL_VERSION == "RHEL7" ]]; then
            ANSIBLE_REPO=$(awk '/rhel7_ansible_repo:/ {print $2}' "${vars_file}")
        fi
       
        if [[ $RHEL_VERSION == "RHEL8" ]] || [[ $RHEL_VERSION == "RHEL7" ]]; then
            CURRENT_REPO=$(sudo subscription-manager repos --list-enabled| awk '/ID:/ {print $3}'|grep ansible)
            # check to make sure the support ansible repo is enabled
            if [ "A${CURRENT_REPO}" != "A${ANSIBLE_REPO}" ]
            then
                sudo subscription-manager repos --disable="${CURRENT_REPO}"
                sudo subscription-manager repos --enable="${ANSIBLE_REPO}"
            fi
        fi 

        if [[ $RHEL_VERSION == "RHEL9" ]]; then
            sudo dnf clean all > /dev/null 2>&1
            sudo dnf install -y -q -e 0 ansible-core git bc bind-utils python3-argcomplete ipcalc rhel-system-roles nmap
            ansible-galaxy collection install community.general
            ansible-galaxy collection install ansible.posix
            ansible-galaxy collection install community.libvirt
            ansible-galaxy collection install fedora.linux_system_roles
            install_podman_dependainces
        elif [[ $RHEL_VERSION == "RHEL8" ]]; then
            sudo dnf clean all > /dev/null 2>&1
            if [ ${RUN_KNI_ON_RHPDS} == "yes" ]
            then
                sudo pip3 install ansible
                sudo dnf install -y -q -e 0  git bc bind-utils python3-argcomplete ipcalc unzip  rhel-system-roles nmap  libvirt-nss
                sudo ln -s /usr/local/bin/ansible /usr/bin/ansible
            else
                sudo dnf install -y -q -e 0 ansible-core git bc bind-utils python3-argcomplete ipcalc rhel-system-roles nmap libvirt-nss
            fi
            install_podman_dependainces
        elif [[ $RHEL_VERSION == "ROCKY8" ]]; then
            sudo dnf clean all > /dev/null 2>&1
            sudo dnf install -y -q -e 0 ansible git bc bind-utils python3-argcomplete ipcalc nmap unzip libvirt-nss
            ansible-galaxy collection install community.general
            ansible-galaxy collection install ansible.posix
            ansible-galaxy collection install community.libvirt
            ansible-galaxy collection install fedora.linux_system_roles
            install_podman_dependainces
        elif [[ $RHEL_VERSION == "RHEL7" ]]; then
            sudo yum clean all > /dev/null 2>&1
            sudo yum install -y -q -e 0 ansible git  bc bind-utils python3-argcomplete ipcalc nmap unzip libvirt-nss
            install_podman_dependainces
        elif [ $(get_distro) == "centos" ]; then
            sudo dnf clean all > /dev/null 2>&1
            sudo dnf install -y -q -e 0 epel-release
            sudo dnf install -y -q -e 0 ansible git  bc bind-utils python3-argcomplete ipcalc nmap unzip libvirt-nss
            ansible-galaxy collection install community.general
            ansible-galaxy collection install ansible.posix
            ansible-galaxy collection install community.libvirt
            ansible-galaxy collection install fedora.linux_system_roles
            ansible-galaxy install linux-system-roles.network
        elif [[ $RHEL_VERSION == "FEDORA" ]]; then
            sudo dnf clean all > /dev/null 2>&1
            sudo dnf install -y -q -e 0 ansible git  bc bind-utils python3-argcomplete ipcalc nmap unzip libvirt-nss openssl
            ansible-galaxy collection install community.general
            ansible-galaxy collection install ansible.posix
            ansible-galaxy collection install community.libvirt
            ansible-galaxy collection install fedora.linux_system_roles
            ansible-galaxy install linux-system-roles.network
            install_podman_dependainces
        fi
       ensure_supported_ansible_version
       echo "completed installing ansible.." >  /tmp/ansible_install.log
    else
        # Update ansible
        printf "%s\n" "   ${mag}Updating ansible ${end}"
        sudo dnf update -y --allowerasing ansible > /dev/null 2>&1
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

	# use the ansible requirements file that matches the current branch
	branch=$(git symbolic-ref HEAD 2>/dev/null| sed -e 's,.*/\(.*\),\1,')

	DEFAULT_ANSIBLE_REQUIREMENTS_FILE="${project_dir}/playbooks/requirements.yml"
    echo $DEFAULT_ANSIBLE_REQUIREMENTS_FILE


	if [ "A${branch}" != "A" ]
	then
	    ANSIBLE_REQUIREMENTS_BRANCH_FILE="${project_dir}/playbooks/requirements.yml"
	    ANSIBLE_REQUIREMENTS_FILE="${ANSIBLE_REQUIREMENTS_BRANCH_FILE}"

	    # create a matching branch requirements file if one does not exist
	    if [ ! -f "$ANSIBLE_REQUIREMENTS_FILE" ]
      then
          cp $DEFAULT_ANSIBLE_REQUIREMENTS_FILE $ANSIBLE_REQUIREMENTS_BRANCH_FILE
		      #revert changes made to the default requirements file
		      git reset HEAD $DEFAULT_ANSIBLE_REQUIREMENTS_FILE
	    fi
	else
	    ANSIBLE_REQUIREMENTS_FILE="${DEFAULT_ANSIBLE_REQUIREMENTS_FILE}"
	fi

        # Ensure roles are downloaded
        if [ "${qubinode_maintenance_opt}" == "ansible" ]
        then
	    printf "%s\n" "   ${mag}Downloading required roles overwriting existing${end}"
            ansible-galaxy install --force -r "${ANSIBLE_REQUIREMENTS_FILE}" > /dev/null 2>&1 || exit $?
            ansible-galaxy install --force -r "collections/requirements.yml"  || exit $?
        else
            printf "%s\n" " ${mag}Downloading required roles${end}"
            ansible-galaxy install --force -r "${ANSIBLE_REQUIREMENTS_FILE}" > /dev/null 2>&1 || exit $?
            ansible-galaxy install --force -r "collections/requirements.yml"|| exit $?
        fi

        # Ensure required modules are downloaded
        if [ ! -f "${project_dir}/module_utils/redhat_repositories.py" ]
        then
            test -d "${project_dir}/module_utils" || mkdir "${project_dir}/module_utils"
            CURRENT_DIR=$(pwd)
            cd "${project_dir}/module_utils/"
            wget https://raw.githubusercontent.com/jfenal/ansible-modules-jfenal/master/packaging/os/redhat_repositories.py
            cd "${CURRENT_DIR}"
        fi
    else
        printf "%s\n" " Ansible not found, please install and retry."
        exit 1
    fi

    sed -i "s/qubinode_installer_ansible_completed:.*/qubinode_installer_ansible_completed: yes/g" "${vars_file}"
    printf "${yel}    Ansible Setup Complete ${end}\n"
    # Push changes to repo
    enable_gitops=$(awk '/enable_gitops:/ {print $2;exit}' "${vars_file}")
    if [ "A${enable_gitops}" == "Atrue" ]
    then
        push_to_repo all.yml
    fi

}

function decrypt_ansible_vault () {
    vaultfile="${project_dir}/playbooks/vars/vault.yml"
    if fgrep -q "VAULT" "${vaultfile}"
    then
        cd "${project_dir}/"
        test -f /usr/bin/ansible-vault && ansible-vault decrypt "${vaultfile}"
        ansible_encrypt=yes
    fi
}

function encrypt_ansible_vault () {
    vaultfile="${project_dir}/playbooks/vars/vault.yml"
    if fgrep -q "VAULT" "${vaultfile}"
    then
        cd "${project_dir}/"
        test -f /usr/bin/ansible-vault && ansible-vault encrypt "${vaultfile}"
    fi
}


function install_podman_dependainces(){
    ansible-galaxy collection install ansible.posix
    ansible-galaxy collection install containers.podman
}
