#!/bin/bash

function elevate_cmd () {
    local cmd=$@

    HAS_SUDO=$(has_sudo)

    case "$HAS_SUDO" in
        user_not_have_sudo)
             printf "%s\n" " Please supply root password for the following command: ${grn}su -c \"$cmd\"${end}"
             su -c "$cmd"
	     current_elevate_cmd='su -c'
             ;;
        user_has_sudo)
            printf "%s\n" " Please supply sudo password for the following command: ${grn}sudo $cmd${end}"
            sudo $cmd
	     current_elevate_cmd="sudo"
            ;;
        *)
            printf "%s\n" " Sudo passwordless is setup for user ${CURRENT_USER}"
            ;;
    esac
}

function setup_sudoers () {
    #sudo -k -n test -f "/etc/sudoers.d/${CURRENT_USER}" >/dev/null 2>&1
    #if [ "$?:-none" != "0" ]
    if ! sudo -k -n test -f "/etc/sudoers.d/${CURRENT_USER}" >/dev/null 2>&1
    then
        printf "%s\n" ""
        printf "%s\n" "     ${cyn}${txu}${txb}Setup Sudoers${txend}${txuend}${end}"
        printf "%s\n" "   The qubinode-installer runs as a normal user. It sets up"
        printf "%s\n" "   your current user account for passwordless sudo."
        printf "%s\n" "   If user ${CURRENT_USER} isn't already setup for sudo, you will"
        printf "%s\n" "   be prompted for the root users password. The installer will"
        printf "%s\n" "   setup sudoers for user ${CURRENT_USER}. If you do not know"
        printf "%s\n" "   the password for the root user, please Ctrl+c to exit now."
        printf "%s\n" ""
        SUDOERS_TMP=$(mktemp)
        printf "%s\n" " Setting up /etc/sudoers.d/${CURRENT_USER}"
	    echo "${CURRENT_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_TMP}"
        sudo_run_cmd=$(mktemp)
        echo "cp ${SUDOERS_TMP} /etc/sudoers.d/${CURRENT_USER}" > "${sudo_run_cmd}"
        echo "chmod 0440 /etc/sudoers.d/${CURRENT_USER}" >> "${sudo_run_cmd}"
        chmod +x "${sudo_run_cmd}"
        elevate_cmd "${sudo_run_cmd}"
        #elevate_cmd cp "${SUDOERS_TMP}" "/etc/sudoers.d/${CURRENT_USER}; chmod 0440 "/etc/sudoers.d/${CURRENT_USER}"
        #"$current_elevate_cmd" chmod 0440 "/etc/sudoers.d/${CURRENT_USER}"
    fi
}

function has_sudo() {
    local user_has_sudo

    # Clear all cached sudo credentials
    sudo -K >/dev/null 2>&1
    user_has_sudo=$(sudo -k -n ls /var/lib/libvirt/images/ 2>&1)
    user_not_have_sudo=$(sudo -k -v -n 2>&1)
    
    if echo "$user_not_have_sudo" | grep -q 'may not run sudo on' >/dev/null 2>&1
    then
        echo "user_not_have_sudo"  
    elif echo "$user_has_sudo" | grep -q 'a password is required' >/dev/null 2>&1
    then
        echo "user_has_sudo" 
    else
        echo "user_has_sudo"
    fi

}