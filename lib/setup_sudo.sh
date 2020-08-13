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

function setup_sudoers () {
    elevate_cmd test -f "/etc/sudoers.d/${CURRENT_USER}"
    if [ "A$?" != "A0" ]
    then
        printf "%s\n" ""
        printf "%s\n" "     ${txu}${txb}Setup Sudoers${txend}${txuend}"
        printf "%s\n" " The qubinode-installer runs as a normal user. It sets up"
        printf "%s\n" " your current user account for passwordless sudo."
        printf "%s\n" ""
        SUDOERS_TMP=$(mktemp)
        printf "%s\n" " Setting up /etc/sudoers.d/${CURRENT_USER}"
	echo "${CURRENT_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_TMP}"
        elevate_cmd cp "${SUDOERS_TMP}" "/etc/sudoers.d/${CURRENT_USER}"
        sudo chmod 0440 "/etc/sudoers.d/${CURRENT_USER}"
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

