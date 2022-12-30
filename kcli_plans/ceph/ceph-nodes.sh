#!/bin/bash
sudo subscription-manager refresh
sudo subscription-manager attach --auto
subscription-manager repos --disable=*
subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
dnf update -y
subscription-manager repos --enable=rhceph-5-tools-for-rhel-8-x86_64-rpms
sleep 30s
nmcli con mod "System eth0" ipv4.dns "192.168.1.39"
sudo nmcli con mod "System eth0" ipv4.dns-search "lab.tosins-supermicro.io"
sudo service NetworkManager restart