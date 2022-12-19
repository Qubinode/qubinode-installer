#!/bin/bash 

for i in {1..3}
do
    num1=3
    num=$((num1 + ${i}))
    echo ceph-mon0${i}
    sudo yq -i '.dns.zones[0].records.A['${num}'].name = "ceph-mon0'${i}'"' /opt/service-containers/config/server.yml
    sudo yq -i '.dns.zones[0].records.A['${num}'].ttl = 6440' /opt/service-containers/config/server.yml
    IP_ADRESS=$(sudo kcli info vm ceph-mon0${i} | grep ip | awk '{print $2}')
    sudo yq -i  '.dns.zones[0].records.A['${num}'].value = "'${IP_ADRESS}'"' /opt/service-containers/config/server.yml
done

for i in {1..3}
do
    num1=6
    num=$((num1 + ${i}))
    echo ceph-osd0${i}
    sudo yq -i '.dns.zones[0].records.A['${num}'].name = "ceph-osd0'${i}'"' /opt/service-containers/config/server.yml
    sudo yq -i '.dns.zones[0].records.A['${num}'].ttl = 6440' /opt/service-containers/config/server.yml
    IP_ADRESS=$(sudo kcli info vm ceph-osd0${i} | grep ip | awk '{print $2}')
    sudo yq -i  '.dns.zones[0].records.A['${num}'].value = "'${IP_ADRESS}'"' /opt/service-containers/config/server.yml
done
./qubinode-installer -p gozones -m restartcontainer
