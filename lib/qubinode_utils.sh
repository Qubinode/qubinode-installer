#!/bin/bash


function qubinode_project_cleanup () {
    # resets the project to a clean state by removing all vars files 
    # ensure requirements are in place
    product_requirements

    FILES=()
    mapfile -t FILES < <(find "${project_dir}/inventory/" -not -path '*/\.*' -type f)
    if [ -f "$vault_vars_file" ] && [ -f "$vault_vars_file" ]
    then
        FILES=("${FILES[@]}" "$vault_vars_file" "$vars_file")
    fi

    # Delete OpenShift files
    openshift_product=$(awk '/^product:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
    if [[ ${openshift_product} == "ocp3" ]]; then
      FILES=("${FILES[@]}" "$ocp3_vars_files")
    elif [[ ${openshift_product} == "okd3" ]]; then
      FILES=("${FILES[@]}" "$okd3_vars_files")
    fi

    if [ ${#FILES[@]} -eq 0 ]
    then
        echo "Project directory: ${project_dir} state is already clean"
    else
        for f in $(echo "${FILES[@]}")
        do
            test -f $f && rm $f
            echo "purged $f"

        done
    fi
}

