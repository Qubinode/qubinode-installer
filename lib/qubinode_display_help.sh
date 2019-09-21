function display_help() {
    setup_required_paths
    SCRIPT="$0"
    cat < "${project_dir}/docs/qubinode-install.adoc"
}
