#!/bin/bash
project_dir_path=$(sudo find / -type d -name qubinode-installer)
project_dir=$project_dir_path
echo ${project_dir}
project_dir="`( cd \"$project_dir_path\" && pwd )`"
vars_file="${vars_file}"
idm_vars_file="${project_dir}/playbooks/vars/idm.yml"

# Get hardware check function for OCP size deployments
source ${project_dir}/lib/qubinode_hardware_check.sh

function checkyamls() {


  if [[  -f $idm_vars_file  ]]; then
    echo "idm yaml exists"
  fi

  if [[  -f ${ocp3_vars_file}  ]]; then
    echo "ocp yaml exists"
    OPENSHIFTYAML=${ocp3_vars_file}
  elif [[  -f ${okd3_vars_file}  ]]; then
    echo "okd yaml exists"
    OPENSHIFTYAML=${okd3_vars_file}
  fi
}

function generate_defaults() {
  if [[ -f ${ocp_defaults_vars_file} ]]; then
    echo "Defaults yaml exists"
  else
    echo "Cannot continue defaults yaml does not exist!"
    exit 1
  fi

cat >${vars_file}<<YAML
  $(cat ${ocp_defaults_vars_file} )
YAML

}

function generate_kvm_host() {
  if [[  -f ${kvm_host_vars_file}  ]]; then
    echo "kvm_host yaml exists"
  else
    echo "Cannot continue kvm_host yaml does not exist!"
    exit 1
  fi

  echo  "
###
# KVM HOST Information
###" >> ${vars_file}
  cat ${kvm_host_vars_file} >> ${vars_file}

}

function generate_idm_product() {
# NOTE: this function should go away
  if [[  -f $idm_vars_file  ]]; then
    echo "idm yaml exists"
  else
    echo "Cannot continue idm yaml does not exist!"
    exit 1
  fi

  echo  "
###
# IDM PRODUCT
###"
#  cat $idm_vars_file >> ${vars_file}
}

function generate_ocp_product() {
  productname=$(awk '/^openshift_product:/ {print $2}' "${vars_file}")
  if [[ $productname == "ocp" ]]; then
    if [[  -f ${ocp3_vars_file}  ]]; then
        OPENSHIFTYAML=${ocp3_vars_file}
      echo "ocp3 yaml exists"
    else
      echo "Cannot continue ocp3 yaml does not exist!"
      exit 1
    fi
  elif [[ $productname == "okd"  ]]; then
    if [[  -f ${okd3_vars_file}  ]]; then
      OPENSHIFTYAML=${okd3_vars_file}
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
  cat $OPENSHIFTYAML >> ${vars_file}
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
