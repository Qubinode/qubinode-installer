#########################
Configure two routers using BGP 
#########################

https://docs.vyos.io/en/latest/configuration/protocols/bgp.html

Configuration
=============

Node 1
```
ROUTER_1_IP=192.168.1.25 
ROUTER_2_IP=192.168.1.24
TARGET_SUBNET=192.168.11.0/24
cat >configure_bgp.sh<<EOF
source /opt/vyatta/etc/functions/script-template
set policy route-map setmet rule 2 action 'permit'
set policy route-map setmet rule 2 set as-path prepend '2 2 2'
set protocols bgp system-as 65534
set protocols bgp neighbor ${ROUTER_2_IP} ebgp-multihop '2'
set protocols bgp neighbor ${ROUTER_2_IP} remote-as '65535'
set protocols bgp neighbor ${ROUTER_2_IP} update-source '${ROUTER_1_IP}'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast route-map import 'setmet'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast soft-reconfiguration 'inbound'
set protocols bgp address-family ipv4-unicast network '${TARGET_SUBNET}'
set protocols bgp parameters router-id '${ROUTER_1_IP}'
commit 
save
exit
EOF
$ chmod +x configure_bgp.sh
$ bash configure_bgp.sh
$ show ip bgp summary
$ show ip bgp neighbors 192.168.1.24 routes
$ ping 192.168.14.1
```

Node 2
```
ROUTER_1_IP=192.168.1.24 
ROUTER_2_IP=192.168.1.25
TARGET_SUBNET=192.168.14.0/24
cat >configure_bgp.sh<<EOF
source /opt/vyatta/etc/functions/script-template
set policy route-map setmet rule 2 action 'permit'
set policy route-map setmet rule 2 set as-path prepend '2 2 2'
set protocols bgp system-as 65535
set protocols bgp neighbor ${ROUTER_2_IP} ebgp-multihop '2'
set protocols bgp neighbor ${ROUTER_2_IP} remote-as '65534'
set protocols bgp neighbor ${ROUTER_2_IP} update-source '${ROUTER_1_IP}'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast route-map import 'setmet'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast soft-reconfiguration 'inbound'
set protocols bgp address-family ipv4-unicast network '${TARGET_SUBNET}'
set protocols bgp parameters router-id '${ROUTER_1_IP}'
commit 
save
exit
EOF

$ chmod +x configure_bgp.sh
$ bash configure_bgp.sh
$ show ip bgp summary
$ show ip bgp neighbors 192.168.1.25 routes
$ ping 192.168.11.1
```