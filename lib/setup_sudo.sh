#!/bin/bash

function elevate_cmd () {
    local cmd=$@

    HAS_SUDO=$(has_sudo)

    case "$HAS_SUDO" in
    has_sudo__pass_set)
        sudo $cmd
        ;;
    has_sudo__needs_pass)
        printf "%s\n" " Please supply sudo password for the following command: ${grn}sudo $cmd${end}"
        sudo $cmd
        ;;
    *)
        printf "%s\n" " Please supply root password for the following command: ${grn}su -c \"$cmd\"${end}"
        su -c "$cmd"
        ;;
    esac
}

#@description
# Executes 'su -c <cmd>'
# @exitcode 0 if successful
function run_su_cmd() {
    # this fucntion is used with setup_sudoers
    local cmd=$@
    su -c "$cmd"
    return $?
}

# @description
# Ask the user for their password.
function ask_for_admin_user_pass () {
    admin_user_password="${ADMIN_USER_PASSWORD:-none}"
    # root user password to be set for virtual instances created
    if [ "A${admin_user_password}" == "Anone" ]
    then
        printf "%s\n\n" ""
        printf "%s\n" " ${blu:?} Admin User Credentials${end:?}"
	    printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
        printf "%s\n" "  Your password for your username ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} is needed to allow"
        printf "%s\n" "  the installer to setup password-less sudoers. Your password"
        printf "%s\n" "  and other secrets will be stored in a encrypted ansible vault file"
	    printf "%s\n\n" "  ${cyn:?}${project_dir}/playbooks/vars/qubinode_vault.yml${end:?}."
        printf "%s\n" "  You can view this file by executing: "
        printf "%s\n\n" "  ${cyn:?}ansible-vault ${project_dir}/playbooks/vars/qubinode_vault.yml ${end:?}"

        MSG_ONE="Enter a password for ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} ${blu:?}[ENTER]${end:?}:"
        MSG_TWO="Enter a password again for ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} ${blu:?}[ENTER]${end:?}:"
        accept_sensitive_input
        admin_user_password="$sensitive_data"
        export ADMIN_USER_PASSWORD="${admin_user_password:-none}"
    fi
}

# @description
# Takes in senstive input from user.
function accept_sensitive_input () {
    printf "%s\n" ""
    printf "%s\n" "  Try not to ${cyn:?}Backspace${end:?} to correct a typo, "
    printf "%s\n\n" "  you will be prompted again if the input does not match."
    while true
    do
        printf "%s" "  $MSG_ONE"
        read_sensitive_data
        USER_INPUT1="${sensitive_data}"
        printf "%s" "  $MSG_TWO"
        read_sensitive_data
        USER_INPUT2="${sensitive_data}"
        if [ "$USER_INPUT1" == "$USER_INPUT2" ]
        then
	    sensitive_data="$USER_INPUT2"
	    break
	fi
        printf "%s\n"  "  ${cyn:?}Please try again${end:?}: "
        printf "%s\n" ""
    done
}

#@description
# Adds the current user to sudoers and make it password-less access.
# If this is unsuccessful it will cause the qubinode-installer to exit.
function setup_sudoers () {

    if ! sudo -v >/dev/null 2>&1
    then
    QUBINODE_ADMIN_USER=$(cat "${project_dir}/playbooks/vars/all.yml" | awk '/^admin_user:/ {print $2}')
    VAULT_FILE="${project_dir}/playbooks/vars/vault.yml"
    vault_parse_cmd="cat"
    if which ansible-vault >/dev/null 2>&1
    then
        if ansible-vault view "${VAULT_FILE}" >/dev/null 2>&1
        then
	        vault_parse_cmd="ansible-vault view"
	    fi
    fi

    if [ -f "${VAULT_FILE}" ]
    then
        ADMIN_USER_PASSWORD=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^admin_user_password:/ {print $2}')
        ADMIN_USER_PASSWORD=$(echo $ADMIN_USER_PASSWORD | sed -e 's/^"//' -e 's/"$//')
    fi

    if [[ "${ADMIN_USER_PASSWORD:-none}" == 'none' ]] || [[ "${ADMIN_USER_PASSWORD}" == '""' ]]
    then
        ask_for_admin_user_pass
    fi
  
   local __admin_pass="${ADMIN_USER_PASSWORD:-none}"
   if [ "A${__admin_pass}" == "Anone" ]
   then
       echo "Current user password is required."
       exit 1
   fi
   local TMP_RESULT=$(mktemp)
   local TMP_RESULT2=$(mktemp)
   local HAS_SUDO="none"
   local MSG="We need to setup up your username ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} for sudo password less access."
   local SU_MSG="Your username ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} is not in the sudoers file."
   local SU_MSG2="Please enter the ${cyn:?}root${end:?} user password to setup ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} sudoers."
   local SUDOERS_TMP=$(mktemp)
   local SUDO_MSG="Creating user ${QUBINODE_ADMIN_USER} sudoers file /etc/sudoers.d/${QUBINODE_ADMIN_USER}"
   # clear sudo cache
   sudo -k

   # Check if user is setup for sudo
   echo "$__admin_pass" | sudo -S ls 2> "$TMP_RESULT" 1> /dev/null || HAS_SUDO=no
   echo "${QUBINODE_ADMIN_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_TMP}"
   chmod 0440 "${SUDOERS_TMP}"

   if [ "$HAS_SUDO" == "no" ]
   then
       printf "%s\n" ""
       printf "%s\n" "  ${blu:?}Setup Sudoers${end:?}"
       printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
       printf "%s\n\n" "  ${MSG}"

       if grep -q "${QUBINODE_ADMIN_USER} is not in the sudoers file" "$TMP_RESULT"
       then
           local CMD="cp -f ${SUDOERS_TMP} /etc/sudoers.d/${QUBINODE_ADMIN_USER}"
           printf "%s\n" "  ${SU_MSG}"
	       confirm "  Continue setting up sudoers for ${QUBINODE_ADMIN_USER}? ${cyn:?}yes/no${end:?}"
	       if [ "A${response}" == "Ano" ]
           then
               printf "%s\n" "  You can manually setup sudoers then re-run the installer."
	           exit 0
	       fi

           ## Use root user password to setuo sudoers
           printf "%s\n" "  ${SU_MSG2}"
           retry=0
           maxRetries=3
           retryInterval=15

           until [ ${retry} -ge ${maxRetries} ]
           do
               run_su_cmd "$CMD" && break
               retry=$[${retry}+1]
               printf "%s\n" "  ${cyn:?}Try again. Enter the root user ${end:?}"
           done

           if [ ${retry} -ge ${maxRetries} ]; then
               printf "%s\n" "   ${red:?}Error: Could not authenicate as the root user.${end:?}"
               exit 1
           fi
       else
           printf "%s\n" "  ${SUDO_MSG}"
           echo "$__admin_pass" | sudo -S cp -f "${SUDOERS_TMP}" "/etc/sudoers.d/${QUBINODE_ADMIN_USER}" > /dev/null 2>&1
           echo "$__admin_pass" | sudo -S chmod 0440 "/etc/sudoers.d/${QUBINODE_ADMIN_USER}" > /dev/null 2>&1
       fi
   fi

   # Confirm sudo setup
   sudo -k
   echo "$__admin_pass" | sudo -S ls 2> "$TMP_RESULT" 1> /dev/null && HAS_SUDO=yes
   if [ "$HAS_SUDO" == "no" ]
   then
       printf "%s\n" "   ${red:?}Error: Sudo setup was unsuccesful${end:?}"
       exit
   fi
   fi
}



function has_sudo() {
    local prompt

    prompt=$(sudo -n ls 2>&1)
    #prompt=$(sudo -nv 2>&1)
    if [ $? -eq 0 ]
    then
        echo "has_sudo__pass_set"
    elif echo $prompt | grep -q '^sudo:'
    then
        echo "has_sudo__needs_pass"
    else
        echo "no_sudo"
    fi
}

