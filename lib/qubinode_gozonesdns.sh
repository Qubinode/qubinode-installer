#!/bin/bash

#set -xe
function gozones_variables () {
    setup_variables
    gozones_vars_file="${project_dir}/playbooks/vars/gozones-dns.yml"
    vars_file="${project_dir}/playbooks/vars/all.yml"
    kvm_host_vars_file="${project_dir}/playbooks/vars/kvm_host.yml"
    MIRROR_BASE_PATH=$(cat "${gozones_vars_file}" | grep mirror_base_path: | awk '{print $2}'| sed -e 's/^"//' -e 's/"$//')
    MIRROR_VM_HOSTNAME=$(cat "${gozones_vars_file}" | grep mirror_vm_hostname: | awk '{print $2}'| sed -e 's/^"//' -e 's/"$//')
    MIRROR_VM_ISOLATED_BRIDGE_IFACE_IP=$(cat "${gozones_vars_file}" | grep mirror_vm_isolated_bridge_iface_ip: | awk '{print $2}'| sed -e 's/^"//' -e 's/"$//')
    ISOLATED_NETWORK_DOMAIN=$(cat "${vars_file}" | grep ^domain: | awk '{print $2}'| sed -e 's/^"//' -e 's/"$//')
    ISOLATED_NETWORK_CIDR=$(cat "${gozones_vars_file}" | grep isolated_network_cidr: | awk '{print $2}' | sed -e 's/^"//' -e 's/"$//')
    ISOLATED_OCTECT=$(cat "${gozones_vars_file}" | grep isolated_octect: | awk '{print $2}' | sed -e 's/^"//' -e 's/"$//')
    FORWARD_IP=$(cat "${gozones_vars_file}" | grep forward_ip: | awk '{print $2}'| sed -e 's/^"//' -e 's/"$//')
    KVM_HOST_IP=$(cat "${kvm_host_vars_file}" | grep kvm_host_ip: | awk '{print $2}'| sed -e 's/^"//' -e 's/"$//')
    ZTPFW_NETWORK_CIDR=$(cat "${gozones_vars_file}" | grep ztpfw_network_cidr: | awk '{print $2}' | sed -e 's/^"//' -e 's/"$//')
}

function ask_user_for_gozones_domain () {

    # ask user for DNS domain or use default
    if grep '""' "${varsfile}"|grep -q domain
    then
        printf "%s\n\n" ""
        printf "%s\n" "  ${yel}****************************************************************************${end}"
        printf "%s\n\n" "    ${cyn}        GoZone DNS${end}"
        printf "%s\n" "   The installer deploys GoZones as a DNS server."
        printf "%s\n\n" "   This requires a DNS domain, accept the default below or enter your own."

        read -p "   Enter your dns domain or press ${mag}[ENTER]${end} for the default domain ${blu}[lab.qubinode.io]: ${end}" domain
        domain=${domain:-lab.qubinode.io}
        sed -i "s/domain: \"\"/domain: "$domain"/g" "${varsfile}"
        printf "%s\n" ""
    fi

    # ask user to enter a upstream dns server or default to 1.1.1.1
    if grep '""' "${varsfile}"|grep -q dns_forwarder
    then
        printf "%s\n\n" ""
        printf "%s\n" "   By default the forwarder for external DNS queries are sent to 1.1.1.1."
        printf "%s\n\n" "   You can change this to any dns server reachable via your network."
        read -p "   Enter an upstream DNS server or press ${mag}[ENTER]${end} for the default ${blue}[1.1.1.1]:${end}" dns_forwarder
        dns_forwarder=${dns_forwarder:-1.1.1.1}
        sed -i "s/dns_forwarder: \"\"/dns_forwarder: "$dns_forwarder"/g" "${varsfile}"
    fi
}

function restartcontianer(){
    sudo systemctl stop dns-go-zones
    sleep 3s
    sudo systemctl start dns-go-zones
    sudo systemctl status dns-go-zones
    gozones_variables
    test_gozones ${ISOLATED_NETWORK_DOMAIN} ${KVM_HOST_IP}
}

function remove_gozones(){
    kcli delete network bare-net -y
    kcli delete network ztpfw -y
    sudo systemctl stop dns-go-zones
    sudo systemctl disable dns-go-zones
    sudo rm -rf  /etc/systemd/system/dns-go-zones.service
    sudo systemctl daemon-reload
    sudo rm -rf ${1}
    if [ $( sudo podman ps -qa -f status=running | wc -l) -eq 1 ]; then
        sudo podman stop $(sudo podman ps | grep dns-go-zones | awk '{print $1}')
    fi 
    sudo podman rm $(sudo podman ps -a | grep dns-go-zones | awk '{print $1}')
}

function qubinode_gozones_maintenance () {
    case ${product_maintenance} in
       removegozones)
           gozones_variables
           remove_gozones ${MIRROR_BASE_PATH}
           ;;
       restartcontainer)
           restartcontianer
           ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}


function configure_libvirt_networks(){
    ### libvirt networks 
   
    echo "kcli create network --nodhcp -c ${1} ztpfw"
    kcli create network --nodhcp -c ${1} ztpfw
    echo "kcli create network -c ${2} bare-net"
    kcli create network -c ${2} bare-net
}

function disable_ivp6(){
    # Go Zones Does not currently work with IPv6
sudo tee /etc/sysctl.d/ipv6.conf > /dev/null <<EOT
    net.ipv6.conf.all.disable_ipv6 = 1
    net.ipv6.conf.default.disable_ipv6 = 1
    net.ipv6.conf.lo.disable_ipv6 = 1
EOT
    sudo sysctl -p /etc/sysctl.d/ipv6.conf
    cat /proc/sys/net/ipv6/conf/all/disable_ipv6
}


function start_deployment(){
    # Create the YAML File
    sudo mkdir -p ${1}/dns/volumes/go-zones/
    sudo mkdir -p ${1}/dns/volumes/bind/
    sudo curl -L https://raw.githubusercontent.com/kenmoini/go-zones/main/container_root/opt/app-root/vendor/bind/named.conf  --output ${1}/dns/volumes/bind/named.conf
    sudo ls -alth  ${1}/dns/volumes/bind/named.conf || exit $?

sudo tee  ${1}/dns/volumes/go-zones/zones.yml > /dev/null <<EOT
zones:
  - name: ${2}
    subnet: ${3}
    network: internal
    primary_dns_server: ${4}.${2}
    ttl: 3600
    records:
      NS:
        - name: ${4}
          ttl: 86400
          domain: ${2}.
          anchor: '@'
      A:
        - name: ${4}
          ttl: 6400
          value: ${5}
        - name: api.ocp4
          ttl: 6400
          value: ${6}.253
        - name: api-int.ocp4
          ttl: 6400
          value: ${6}.253
        - name: '*.apps.ocp4'
          ttl: 6400
          value: ${6}.252
EOT

    ## Create a forwarder file to redirect all other inqueries to this Mirror VM
    sudo mkdir -p ${1}/dns/volumes/bind/
sudo tee ${1}/dns/volumes/bind/external_forwarders.conf> /dev/null <<EOT
    forwarders {
    127.0.0.53;
    ${FORWARD_IP};
    };
EOT

    sudo podman run -d --name dns-go-zones \
    --net host \
    -m 512m \
    -v ${1}/dns/volumes/go-zones:/etc/go-zones/:Z \
    -v ${1}/dns/volumes/bind:/opt/app-root/vendor/bind/:Z \
    quay.io/kenmoini/go-zones:file-to-bind || exit 1

    sudo podman generate systemd \
        --new --name dns-go-zones \
        | sudo tee /etc/systemd/system/dns-go-zones.service
}


function start_service(){
    sudo systemctl enable dns-go-zones
    sudo systemctl start dns-go-zones
    #sudo systemctl status dns-go-zones
    sudo firewall-cmd --add-service=dns --permanent
    sudo firewall-cmd --reload
}


function test_gozones(){
    gozones_variables
    dig  @127.0.0.1 test.apps.ocp4.${1} || exit 1
    dig  @127.0.0.1 test.apps.ocp4.${1} || exit 1
    dig  @${2} test.apps.ocp4.${1} || exit 1
}

function qubinode_setup_gozones() {
    if [ $( sudo podman ps -qa -f status=running | wc -l) -eq 0 ]; then
        gozones_variables 
        configure_libvirt_networks ${ZTPFW_NETWORK_CIDR}  ${ISOLATED_NETWORK_CIDR} 
        disable_ivp6
        start_deployment ${MIRROR_BASE_PATH}  $ISOLATED_NETWORK_DOMAIN  $ISOLATED_NETWORK_CIDR $MIRROR_VM_HOSTNAME $MIRROR_VM_ISOLATED_BRIDGE_IFACE_IP ${ISOLATED_OCTECT}
        start_service
        test_gozones ${ISOLATED_NETWORK_DOMAIN} ${KVM_HOST_IP}
    elif [ $( sudo podman ps -qa -f status=exited ) ]; then
        gozones_variables 
        remove_gozones ${MIRROR_BASE_PATH}
        configure_libvirt_networks ${ZTPFW_NETWORK_CIDR}  ${ISOLATED_NETWORK_CIDR} 
        disable_ivp6
        start_deployment ${MIRROR_BASE_PATH}  $ISOLATED_NETWORK_DOMAIN  $ISOLATED_NETWORK_CIDR $MIRROR_VM_HOSTNAME $MIRROR_VM_ISOLATED_BRIDGE_IFACE_IP ${ISOLATED_OCTECT}
        start_service
        test_gozones ${ISOLATED_NETWORK_DOMAIN} ${KVM_HOST_IP}
    elif [ $( sudo podman ps -qa -f status=running | wc -l ) -gt 0 ]; then
      echo "gozones is installed"
      gozones_variables
      test_gozones ${ISOLATED_NETWORK_DOMAIN} ${KVM_HOST_IP}
    fi 
    exit 
}
