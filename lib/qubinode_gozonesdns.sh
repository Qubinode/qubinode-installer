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
    #kcli delete network bare-net -y
    #kcli delete network ztpfw -y
    sudo systemctl stop dns-go-zones
    sudo systemctl disable dns-go-zones
    sudo rm -rf  /etc/systemd/system/dns-go-zones.service
    sudo systemctl daemon-reload
    sudo rm -rf  ${1}/config
    if [ $( sudo podman ps -qa -f status=running | wc -l) -eq 1 ]; then
        sudo podman stop $(sudo podman ps | grep dns-go-zones | awk '{print $1}')
    fi 
    sudo podman rm $(sudo podman ps -a | grep dns-go-zones | awk '{print $1}')
    update_resolv_conf $FORWARD_IP
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
    sudo mkdir -p ${1}/config

sudo tee  ${1}/config/config.yml > /dev/null <<EOT
app:

  server:
    host: 0.0.0.0
    base_path: "/app"
    port: 8080
    timeout:
      server: 30
      read: 15
      write: 10
      idle: 5
EOT
if [ -f "${project_dir}/samples/dns-server.yml" ];
then 
  sudo cp "${project_dir}/samples/dns-server.yml" "${1}/config/server.yml"
else
sudo tee   ${1}/config/server.yml > /dev/null <<EOT
# example DNS Server Configuration
dns:
  ##########################################################################################
  # acls is a list of named network groups
  acls:
    # privatenets can respond to internal client queries with an internal IP
    - name: privatenets
      networks:
        - 10.0.0.0/8
        - 172.16.0.0/12
        - 192.168.0.0/16
        - localhost
        - localnets
    # externalwan would match any external network
    - name: externalwan
      networks:
        - any
        - "!10.0.0.0/8"
        - "!172.16.0.0/12"
        - "!192.168.0.0/16"
        - "!localhost"
        - "!localnets"

  ##########################################################################################
  # views is a list of named views that glue together acls and zones
  views:
    - name: internalNetworks
      # acls is a list of the named ACLs from above that this view will be applied to
      acls:
      - privatenets
      # recursion is a boolean that controls whether this view will allow recursive DNS queries
      recursion: true
      # if recursion is true, then you can provide forwarders to be used for recursive queries 
      #  such as a PiHole DNS server or just something like Cloudflare DNS at 1.0.0.1 and 1.1.1.1
      forwarders:
      - 1.1.1.1
      - 1.0.0.1
      # zones is a list of named Zones to associate with this view
      zones:
      - qubinode-network
  zones:
    - name: qubinode-network
      zone:  ${2}
      primary_dns_server: ${4}.${2}
      default_ttl: 3600
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
            value: ${6}.253/24
          - name: api-int.ocp4
            ttl: 6400
            value: ${6}.253
          - name: '*.apps.ocp4'
            ttl: 6400
            value: ${6}.252
EOT
fi 

    #sudo podman run -d --name dns-go-zones \
    #--net host \
    #-m 512m \
    #-v ${1}/dns/volumes/go-zones:/etc/go-zones/:Z \
    #-v ${1}/dns/volumes/bind:/opt/app-root/vendor/bind/:Z \
    #quay.io/kenmoini/go-zones:file-to-bind || exit 1
    sudo sed -i 's/enforcing/permissive/g' /etc/selinux/config
    sudo setenforce 0
    sudo podman run --name dns-go-zones -d -p 53 -m 512m --net host -v  "${1}"/config:/etc/go-zones:Z quay.io/kenmoini/go-zones:file-to-bind-latest || exit 1
    sudo podman ps 
    sudo podman ps -a 
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
    if [ $( sudo podman ps -a -f name='dns-go-zones' -f status=running | wc -l) -eq 0 ]; then
        gozones_variables 
        configure_libvirt_networks ${ZTPFW_NETWORK_CIDR}  ${ISOLATED_NETWORK_CIDR} 
        disable_ivp6
        start_deployment ${MIRROR_BASE_PATH}  $ISOLATED_NETWORK_DOMAIN  $ISOLATED_NETWORK_CIDR $MIRROR_VM_HOSTNAME $MIRROR_VM_ISOLATED_BRIDGE_IFACE_IP ${ISOLATED_OCTECT}
        start_service
        test_gozones ${ISOLATED_NETWORK_DOMAIN} ${KVM_HOST_IP}
        update_resolv_conf  ${KVM_HOST_IP}
    elif [ $( sudo podman ps -qa  -f name='dns-go-zones' -f status=exited ) ]; then
        gozones_variables 
        remove_gozones ${MIRROR_BASE_PATH}
        configure_libvirt_networks ${ZTPFW_NETWORK_CIDR}  ${ISOLATED_NETWORK_CIDR} 
        disable_ivp6
        start_deployment ${MIRROR_BASE_PATH}  $ISOLATED_NETWORK_DOMAIN  $ISOLATED_NETWORK_CIDR $MIRROR_VM_HOSTNAME $MIRROR_VM_ISOLATED_BRIDGE_IFACE_IP ${ISOLATED_OCTECT}
        start_service
        test_gozones ${ISOLATED_NETWORK_DOMAIN} ${KVM_HOST_IP}
        update_resolv_conf  ${KVM_HOST_IP}
    elif [ $( sudo podman ps -qa -f name='dns-go-zones' -f status=running | wc -l ) -gt 0 ]; then
      echo "gozones is installed"
      gozones_variables
      test_gozones ${ISOLATED_NETWORK_DOMAIN} ${KVM_HOST_IP}
    fi 
    exit 
}
