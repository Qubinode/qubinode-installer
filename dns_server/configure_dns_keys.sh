#!/bin/bash
# Author: Tosin Akinosho
# Configure keys for bind server
# http://movingpackets.net/2013/06/10/bind-enabling-tsig-for-zone-transfers/

set -x
if [[ -z $1 ]]; then
  echo "Please pass key name."
  echo "Usage: $0 example_key domain_name zone_name"
  exit 1
fi

KEYNAME=$1
SERVER_IP=$2
ZONE_NAME=$3

cd  /etc/named

if [[ ! -f K${KEYNAME}.*.key ]]; then
  dnssec-keygen -a HMAC-MD5 -b 128 -n HOST ${KEYNAME}. || exit 1

  SECERT=$(cat K${KEYNAME}.*.key | awk '{print $7}')
cat <<EOF > /etc/named/${KEYNAME}.
key ${KEYNAME} {
    algorithm hmac-md5;
    secret "${SECERT}";
};
EOF

DNSSERVERIP=$(hostname --ip-address | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
cat  <<EOF > /var/named/${KEYNAME}
\$ORIGIN ${ZONE_NAME}.
\$TTL 1W

@ IN SOA dnsserver.${ZONE_NAME}. hostmaster.${ZONE_NAME}. (
  19031602
  1D
  1H
  1W
  1D )

                     IN  NS     dnsserver.${ZONE_NAME}.


dnsserver            IN A     ${DNSSERVERIP}
EOF

  sed -i '/include "\/etc\/named.rfc1912.zones";/a include "\/etc\/named\/'${KEYNAME}'.";' /etc/named.conf || exit 1
  sed -i   's/allow-update { none; };/allow-update { key '${KEYNAME}'. ;  '${SERVER_IP}' ; };/g' /etc/named.conf || exit 1

  systemctl restart named || exit 1
elif grep -q "/etc/named/${KEYNAME}." /etc/named.conf; then
  echo "Skipping ${KEYNAME} configuration"
fi
