function qubinode_installer_setup () {
    # Run required functions
    setup_sudoers
    setup_variables
    qubinode_required_prereqs
    setup_user_ssh_key
    ask_user_input
    sed -i "s/qubinode_installer_setup_completed:.*/qubinode_installer_setup_completed: yes/g" "${vars_file}"
    printf "\n\n${yel}    ***************************${end}\n"
    printf "${yel}    *   Setup is complete   *${end}\n"
    printf "${yel}    ***************************${end}\n\n"
}
