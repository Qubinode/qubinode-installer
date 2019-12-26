#!/bin/bash

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

function setup_sudoers () {
    printf "\n Checking if ${yel}${CURRENT_USER}${end} is setup for password-less sudo: \n"
    elevate_cmd test -f "/etc/sudoers.d/${CURRENT_USER}"
    if [ "A$?" != "A0" ]
    then
        SUDOERS_TMP=$(mktemp)
        printf "\nSetting up /etc/sudoers.d/${CURRENT_USER}"
	echo "${CURRENT_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_TMP}"
        elevate_cmd cp "${SUDOERS_TMP}" "/etc/sudoers.d/${CURRENT_USER}"
        sudo chmod 0440 "/etc/sudoers.d/${CURRENT_USER}"
    else
        printf "\n ${yel}${CURRENT_USER}${end} is setup for password-less sudo"
    fi
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

