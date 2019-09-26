#!/bin/bash
project_dir_path=$(sudo find / -type d -name qubinode-installer)
project_dir=$project_dir_path
echo ${project_dir}
project_dir="`( cd \"$project_dir_path\" && pwd )`"
vars_file="${project_dir}/playbooks/vars/all.yml"

# Get hardware check function for OCP size deployments
source ${project_dir}/lib/qubinode_hardware_check.sh

function checkyamls() {


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

function generate_defaults() {
  if [[ -f $project_dir/playbooks/vars/defaults.yml ]]; then
    echo "Defaults yaml exists"
  else
    echo "Cannot continue defaults yaml does not exist!"
    exit 1
  fi

cat >${project_dir}/playbooks/vars/all.yml<<YAML
  $(cat $project_dir/playbooks/vars/defaults.yml )
YAML

}

function generate_kvm_host() {
  if [[  -f $project_dir/playbooks/vars/kvm_host.yml  ]]; then
    echo "kvm_host yaml exists"
  else
    echo "Cannot continue kvm_host yaml does not exist!"
    exit 1
  fi

  echo  "
###
# KVM HOST Information
###" >> ${project_dir}/playbooks/vars/all.yml
  cat $project_dir/playbooks/vars/kvm_host.yml >> ${project_dir}/playbooks/vars/all.yml

}

function generate_idm_product() {
  if [[  -f $project_dir/playbooks/vars/idm.yml  ]]; then
    echo "idm yaml exists"
  else
    echo "Cannot continue idm yaml does not exist!"
    exit 1
  fi

  echo  "
###
# IDM PRODUCT
###"
  cat $project_dir/playbooks/vars/idm.yml >> ${project_dir}/playbooks/vars/all.yml
}

function generate_ocp_product() {
  productname=$(awk '/^product:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
  if [[ $productname == "ocp" ]]; then
    if [[  -f $project_dir/playbooks/vars/ocp3.yml  ]]; then
        OPENSHIFTYAML=$project_dir/playbooks/vars/ocp3.yml
      echo "ocp3 yaml exists"
    else
      echo "Cannot continue ocp3 yaml does not exist!"
      exit 1
    fi
  elif [[ $productname == "okd"  ]]; then
    if [[  -f $project_dir/playbooks/vars/okd3.yml  ]]; then
      OPENSHIFTYAML=$project_dir/playbooks/vars/okd3.yml
      echo "okd3 yaml exists"
    else
      echo "Cannot continue okd3 yaml does not exist!"
      exit 1
    fi
  else
    echo "Cannot continue OpenShift type  does not exist!"
    exit 1
  fi

  echo  "
###
#  Openshift Product
###"
  cat $OPENSHIFTYAML >> ${project_dir}/playbooks/vars/all.yml
}

case ${1} in

  defaults)
    generate_defaults
    ;;

  kvm_host)
    generate_kvm_host
    ;;

  idm)
    generate_idm_product
    ;;
  ocp)
    generate_ocp_product
    check_hardware_resources $project_dir
    ;;
  okd)
    generate_ocp_product
    check_hardware_resources $project_dir
    ;;
  *)
    echo "Incorrect Flag passed"
    exit 1
    ;;
esac




###
# Openshift Product
###
#$(cat $OPENSHIFTYAML)

###
# OpenShift VM Sizing
###
