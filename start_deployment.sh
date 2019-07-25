#!/usr/bin/env bash
# This script will start the automated depoyment of openshift home lab

# Uncomment for debugging
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

OPENSHIFT_RELEASE_VERSION="v3.11.98"
DEFAULT_PRODUCT="ocp"
VALID_PRODUCTS="okd ${DEFAULT_PRODUCT}"
#########################
# import functions      #
#########################
#source dns_server/lib/dns_functions.sh
#########################
# The command line help #
#########################
function display_help() {
    SCRIPT=$(basename "${BASH_SOURCE[0]}")

    cat << EOH >&2
Basic usage: ${SCRIPT} [options]
    -i      Interactivly generate the inventory
    -p      Deploy okd or ocp: default is ocp
                   ---    ---             ---
    -s      Skip DNS server deployment
    -h      Display this help menu
EOH
}

function check_args () {
    if [[ $OPTARG =~ ^-[h/p/i]$ ]]
    then
      echo "Invalid option argument $OPTARG, check that each argument has a value." >&2
      exit 1
    fi
}

function deploy_dns_server () {
    source "${PROJECT_DIR}/dns_server/lib/dns_functions.sh"
    #$2 = domainname
    configurednsforopenshift $2 centos
}

while getopts ":hip:" opt;
do
    case $opt in
        h) display_help
           exit 1
           ;;
        i) check_args; generate_inventory=true;;
        p) check_args
           product=$OPTARG
           ;;
        s) check_args; skip_dns=true;;
       --) shift; break;;
       -*) echo Unrecognized flag : "$1" >&2
           display_help
           exit 1
           ;;
       \?) echo Unrecognized flag : "$1" >&2
           display_help
           exit 1
           ;;
    esac
done
shift "$((OPTIND-1))"

# validate product
for item in $(echo "$VALID_PRODUCTS")
do
    if [ "A${product}" == "A${item}" ];
    then
        product="${product}"
        break
    else
        product="${DEFAULT_PRODUCT}"
    fi
done
