#!/bin/bash

## This script does post configuration of openshift certs

## Function to create a menu
function createmenu () {
    select selected_option; do # in "$@" is the default
        if [ "$REPLY" -eq "$REPLY" 2>/dev/null ]
        then
            if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $(($#)) ]; then
                break;
            else
                echo "    Please make a vaild selection (1-$#)."
            fi
         else
            echo "    Please make a vaild selection (1-$#)."
         fi
    done
}

get_user_input () {
    ## Present user with options for DNS providers supported
    declare -a DNS_PROVIDERS=(Cloudflare Godaddy SelfSigned)
    echo "Choose your DNS provider: "
    createmenu "${DNS_PROVIDERS[@]}"
    DNS_PROVIDER=($(echo "${selected_option}"))

    ## Gather information for Let's Encrypt Registration
    read -p 'What is the email address you would like to use with Lets Encrypt? ' user_email_address
    read -p "What is your domain registered with ${DNS_PROVIDER}? " user_domain
    read -p 'Enter a description for your SSL cert: ' user_agent

    ## Set the default DNS provider
    use_cloudflare=no
    use_godaddy=no
    use_selfsigned=no

    if [ "A${DNS_PROVIDER}" == "ACloudflare" ]
    then
        use_cloudflare=yes
        read -p 'What is your Cloudflare token?' cloudflare_token
        read -p 'What is your Cloudflare Account ID?' cloudflare_account_id
        read -p 'What is your Cloudflare Zone ID?' cloudflare_zone_id
    elif [ "A${DNS_PROVIDER}" == "AGodaddy" ]
    then
        use_godaddy=yes
    elif [ "A${DNS_PROVIDER}" == "ASelfSigned" ]
    then
        use_selfsigned=yes
    else
        use_selfsigned=yes
    fi
}

## MAIN

## check if oc commands exist and setup required variables
if which oc >/dev/null
then
    if oc whoami --show-server >/dev/null
    then
        LE_API=$(oc whoami --show-server | cut -f 2 -d ':' | cut -f 3 -d '/' | sed 's/-api././')
        LE_WILDCARD=$(oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.domain}')
    else
        echo "Could not indentify OpenShift server"
        exit 1
    fi
else
    echo "Coulld not find oc command"
    exit 1
fi

## Set arguments for playbook run
extra_vars="${HOME}/qubinode-installer/playbooks/vars/ocp4_certs.yml"
if [ -f ${HOME}/qubinode-installer/acme/bin/acme.sh ]
then
    if ${HOME}/qubinode-installer/acme/bin/acme.sh --list | grep -q $LE_API
    then
        PLAYBOOK_ARG="--extra-vars="@${extra_vars}" --extra-vars="skip_acme=yes""
    fi
else
    PLAYBOOK_ARG="--extra-vars="@${extra_vars}""
fi

if [ ! -f ${HOME}/qubinode-installer/playbooks/vars/ocp4_certs.yml ]
then
    get_user_input
## Write out Ansible vars file
cat >> ${HOME}/qubinode-installer/playbooks/vars/ocp4_certs.yml <<EOF
---
le_wildcard: $LE_WILDCARD
le_api: $LE_API
use_cloudflare: $use_cloudflare
use_selfsigned: $use_selfsigned
use_godaddy:  $use_godaddy
user_email_address: $user_email_address
user_domain: $user_domain
user_agent: '$user_agent'
cloudflare_token: $cloudflare_token
cloudflare_account_id: $cloudflare_account_id
cloudflare_zone_id: $cloudflare_zone_id
EOF
fi

if [  -f ${HOME}/qubinode-installer/playbooks/vars/ocp4_certs.yml ]
then
    ## Run ansible playbook
    echo ansible-playbook ${HOME}/qubinode-installer/playbooks/install-lets-encrypt-certificates.yml "${PLAYBOOK_ARG}"|sh
fi

exit 0
