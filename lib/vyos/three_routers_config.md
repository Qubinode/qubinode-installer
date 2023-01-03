# Configure three or more routers using BGP
The below example will configure three routers using BGP.  This can be modified if more than three are needed. The routers will be configured with the following:


**Offfical Documentation:**
* https://docs.vyos.io/en/latest/configuration/protocols/bgp.html

Configuration
=============

* Router 1
  * ssh to router 1
  * example: ssh vyos@192.168.1.25
```
ROUTER_1_IP=192.168.1.25 
ROUTER_2_IP=192.168.1.24
ROUTER_3_IP=192.168.1.23
TARGET_SUBNET=192.168.11.0/24
cat >configure_bgp.sh<<EOF
source /opt/vyatta/etc/functions/script-template
set policy route-map setmet rule 2 action 'permit'
set policy route-map setmet rule 2 set as-path prepend '2 2 2'
set protocols bgp system-as 65534
set protocols bgp neighbor ${ROUTER_2_IP} ebgp-multihop '3'
set protocols bgp neighbor ${ROUTER_2_IP} remote-as '65535'
set protocols bgp neighbor ${ROUTER_2_IP} update-source '${ROUTER_1_IP}'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast route-map import 'setmet'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast soft-reconfiguration 'inbound'
set protocols bgp neighbor ${ROUTER_3_IP} ebgp-multihop '3'
set protocols bgp neighbor ${ROUTER_3_IP} remote-as '65536'
set protocols bgp neighbor ${ROUTER_3_IP} update-source '${ROUTER_1_IP}'
set protocols bgp neighbor ${ROUTER_3_IP} address-family ipv4-unicast route-map import 'setmet'
set protocols bgp neighbor ${ROUTER_3_IP} address-family ipv4-unicast soft-reconfiguration 'inbound'
set protocols bgp address-family ipv4-unicast network '${TARGET_SUBNET}'
set protocols bgp parameters router-id '${ROUTER_1_IP}'
set protocols static route 192.168.11.0/24 blackhole distance '254'
commit 
save
exit
EOF

$ chmod +x configure_bgp.sh
$ bash configure_bgp.sh
$ show ip bgp summary
```

* **Router 2**
  * ssh to router 2
  * example:  ssh vyos@192.168.1.24
```
ROUTER_1_IP=192.168.1.24 
ROUTER_2_IP=192.168.1.25
ROUTER_3_IP=192.168.1.23
TARGET_SUBNET=192.168.14.0/24
cat >configure_bgp.sh<<EOF
source /opt/vyatta/etc/functions/script-template
set policy route-map setmet rule 2 action 'permit'
set policy route-map setmet rule 2 set as-path prepend '2 2 2'
set protocols bgp system-as 65535
set protocols bgp neighbor ${ROUTER_2_IP} ebgp-multihop '3'
set protocols bgp neighbor ${ROUTER_2_IP} remote-as '65534'
set protocols bgp neighbor ${ROUTER_2_IP} update-source '${ROUTER_1_IP}'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast route-map import 'setmet'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast soft-reconfiguration 'inbound'
set protocols bgp neighbor ${ROUTER_3_IP} ebgp-multihop '3'
set protocols bgp neighbor ${ROUTER_3_IP} remote-as '65536'
set protocols bgp neighbor ${ROUTER_3_IP} update-source '${ROUTER_1_IP}'
set protocols bgp neighbor ${ROUTER_3_IP} address-family ipv4-unicast route-map import 'setmet'
set protocols bgp neighbor ${ROUTER_3_IP} address-family ipv4-unicast soft-reconfiguration 'inbound'
set protocols bgp address-family ipv4-unicast network '${TARGET_SUBNET}'
set protocols bgp parameters router-id '${ROUTER_1_IP}'
set protocols static route 192.168.14.0/24 blackhole distance '254'
commit 
save
exit
EOF

$ chmod +x configure_bgp.sh
$ chmod +x configure_bgp.sh
$ bash configure_bgp.sh
$ show ip bgp summary
$ show ip bgp neighbors 192.168.1.23 routes
$ show ip bgp neighbors 192.168.1.25 routes
$ ping 192.168.11.1
$ ping 192.168.17.1
```


* **Router 3**
  * ssh to router 3
  * example: ssh vyos@192.168.1.23
```
ROUTER_1_IP=192.168.1.23 
ROUTER_2_IP=192.168.1.24
ROUTER_3_IP=192.168.1.25
TARGET_SUBNET=192.168.17.0/24
cat >configure_bgp.sh<<EOF
source /opt/vyatta/etc/functions/script-template
set policy route-map setmet rule 2 action 'permit'
set policy route-map setmet rule 2 set as-path prepend '2 2 2'
set protocols bgp system-as 65536
set protocols bgp neighbor ${ROUTER_3_IP} ebgp-multihop '3'
set protocols bgp neighbor ${ROUTER_3_IP} remote-as '65534'
set protocols bgp neighbor ${ROUTER_3_IP} update-source '${ROUTER_1_IP}'
set protocols bgp neighbor ${ROUTER_3_IP} address-family ipv4-unicast route-map import 'setmet'
set protocols bgp neighbor ${ROUTER_3_IP} address-family ipv4-unicast soft-reconfiguration 'inbound'
set protocols bgp neighbor ${ROUTER_2_IP} ebgp-multihop '3'
set protocols bgp neighbor ${ROUTER_2_IP} remote-as '65535'
set protocols bgp neighbor ${ROUTER_2_IP} update-source '${ROUTER_1_IP}'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast route-map import 'setmet'
set protocols bgp neighbor ${ROUTER_2_IP} address-family ipv4-unicast soft-reconfiguration 'inbound'
set protocols bgp address-family ipv4-unicast network '${TARGET_SUBNET}'
set protocols bgp parameters router-id '${ROUTER_1_IP}'
set protocols static route 192.168.17.0/24 blackhole distance '254'
commit 
save
exit
EOF

$ chmod +x configure_bgp.sh
$ bash configure_bgp.sh
$ show ip bgp summary
$ show ip bgp neighbors 192.168.1.24 routes
$ show ip bgp neighbors 192.168.1.25 routes
$ ping 192.168.11.1
$ ping 192.168.17.1
```