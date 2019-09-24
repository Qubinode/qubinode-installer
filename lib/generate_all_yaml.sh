#!/bin/bash
project_dir_path=$(sudo find / -type d -name qubinode-installer)
project_dir=$project_dir_path
echo ${project_dir}
project_dir="`( cd \"$project_dir_path\" && pwd )`"

function checkyamls() {
  if [[ -f $project_dir/playbooks/vars/defaults.yml ]]; then
    echo "Defaults yaml exists"
  else
    echo "Cannot continue defaults yaml does not exist!"
    exit 1
  fi

  if [[  -f $project_dir/playbooks/vars/kvm_host.yml  ]]; then
    echo "kvm_host yaml exists"
  else
    echo "Cannot continue kvm_host yaml does not exist!"
    exit 1
  fi

  if [[  -f $project_dir/playbooks/vars/idm.yml  ]]; then
    echo "idm yaml exists"
  fi

  if [[  -f $project_dir/playbooks/vars/ocp3.yml  ]]; then
    echo "ocp yaml exists"
    OPENSHIFTYAML=$project_dir/playbooks/vars/ocp3.yml
  elif [[  -f $project_dir/playbooks/vars/okd3.yml  ]]; then
    echo "okd yaml exists"
    OPENSHIFTYAML=$project_dir/playbooks/vars/okd3.yml
  fi
}

checkyamls

cat >${project_dir}/playbooks/vars/all.yml<<YAML
$(cat $project_dir/playbooks/vars/defaults.yml )
###
# KVM HOST Information
###
$(cat $project_dir/playbooks/vars/kvm_host.yml )

###
# IDM PRODUCT
###
$(cat $project_dir/playbooks/vars/idm.yml )

###
# Openshift Product
###
$(cat $OPENSHIFTYAML)

###
# OpenShift VM Sizing
###
YAML
