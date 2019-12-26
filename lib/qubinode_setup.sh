function qubinode_installer_setup () {
    # Run required functions
    setup_sudoers
    qubinode_required_prereqs
    setup_user_ssh_key
    setup_variables
    ask_user_input
    printf "\n\n${yel}    ***************************${end}\n"
    printf "${yel}    *   Setup is complete   *${end}\n"
    printf "${yel}    ***************************${end}\n\n"
}
