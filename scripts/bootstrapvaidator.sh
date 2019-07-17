#!/bin/bash
# Author: Tosin Akinosho
# Bootstrap validation script

function askquestions() {
  echo "Generating inventory file for dns server."
  read -p "Enter Domain Name default is example.com: " DOMAINNAME
  read -p "Enter your bind zone networks (Example: 192.168.1): " DNSZONE #Add DNS Zone validation
  read -p "Enter Key Name that Ansible will use to write to dns server: " DNS_KEY_NAME
  read -p "Enter Red Hat Subscription username: " RHEL_USERNAME
  read -s -p "Enter Red Hat Subscription password : " RHEL_PASSWORD
  echo
  read -p "Enter username to login to node: " SSH_USERNAME
  read -s -p "Enter password to login to node: " SSH_PASSWORD
  echo

  validations

# adding variables to environment
cat >bootstrap_env<<EOF
export RHEL_USERNAME=${RHEL_USERNAME}
export RHEL_PASSWORD=${RHEL_PASSWORD}
export DNSZONE=${DNSZONE}
export DEFAULTDNSNAME=${DOMAINNAME}
export SSH_USERNAME=${SSH_USERNAME}
export CREATE_DNS_KEY=TRUE
export DNS_KEY_NAME=${DNS_KEY_NAME}
export SSH_PASSWORD=${SSH_PASSWORD}
EOF

  source bootstrap_env

}

function validations() {
  if [[ -z ${DOMAINNAME} ]]; then
  DOMAINNAME="example.com"
  DEFAULTDNSNAME=$DOMAINNAME
  fi

  if [[ -z ${DNSZONE} ]]; then
  DNSZONE="192.168.1"
  fi


  RHEL_IMAGE=$(ls /kvm/kvmdata/rhel-server-7.6-x86_64-kvm.qcow2  2>/dev/null)
  if [[ -z $RHEL_IMAGE ]]; then
  cp /opt/kvmimage/rhel-server-7.6-x86_64-kvm.qcow2 /kvm/kvmdata/
  fi

  CHECK_ANSIBLE_ROLES=$(ls /etc/ansible/roles 2>/dev/null)
  if [[ -z $CHECK_ANSIBLE_ROLES ]]; then
  cp -ai /opt/ansible-plugins/* /etc/ansible/roles
  fi

  CHECK_SUBSCRIPTION_STATUS=$( subscription-manager status  | grep 'Overall Status' | awk '{print $3}')
  if [[ $CHECK_SUBSCRIPTION_STATUS != Current ]]; then
    read -p "Would you like to register your $(dmidecode -s baseboard-manufacturer) server with Red Hat? " yn
    case $yn in
        [Yy]* )
          subscription-manager register --username ${RHEL_USERNAME} --password ${RHEL_PASSWORD} --auto-attach
          break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
  fi
}


function running_install_check() {
  CHECKFOR_OCP_INSTALLATION=$(virsh list | grep running | wc -l)
  CHECKFOR_OCP_INSTALLATION_SHUTDOWN=$(virsh list | grep shutdown | wc -l)
  if [[ $CHECKFOR_OCP_INSTALLATION -eq 7 ]] ; then
    while true; do
      read -p "A previous running installation of OpenShift has been found. Would you like to continue this will will your current deployment? " yn
      case $yn in
          [Yy]* )./delete_openshift_deployment.sh inventory.rhel.openshift DELLALL; break;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
    done
  elif [[ $CHECKFOR_OCP_INSTALLATION_SHUTDOWN -eq 7 ]] ; then
    while true; do
      read -p "A previous installation of OpenShift has been found. Would you like to continue this will will your current deployment? " yn
      case $yn in
          [Yy]* )./delete_openshift_deployment.sh inventory.rhel.openshift DELLALL; break;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
    done
  else
    CHECKFOR_DNS=$(virsh list | grep running | grep dnsserver | wc -l)
    if [[ $CHECKFOR_DNS -ne 1 ]]; then
      ./delete_openshift_deployment.sh inventory.rhel.openshift DELLALL;
    fi
  fi

}
