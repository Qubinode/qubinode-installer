#!/bin/bash

# Reads in a openshift pull secret and returns YAML with all
# the required registries for ocp deployment.

echo "registry_pods:"
port_num="5000"
cat $1|jq .|grep -B1 auth.:|xargs -n5|awk '{ print $1,$4}'|while read site auth
do
        my_login="$(echo $auth|base64 -id|cut -f1 -d:)"
        my_pwd="$(echo $auth|base64 -id|cut -f2 -d: |sed -e 's@,$@@')"
        my_url="$(echo $site|cut -f1 -d:)"
	if [ "${my_url}" == 'cloud.openshift.com' ]
	then
	    name="reg-cloud-ocp"
	elif [ "${my_url}" == 'quay.io' ]
	then
	    name="reg-quay"
            echo -e "  - name: reg-quay-cdn"
            echo -e "    remoteurl: https://cdn02.quay.io"
            echo -e "    username: '"$my_login"'"
            echo -e "    password: '"$my_pwd"'"
            echo -e "    port: 5004"
	elif [ "${my_url}" == 'registry.connect.redhat.com' ]
	then
	    name="reg-connect-rh"
	elif [ "${my_url}" == 'registry.redhat.io' ]
	then
	    name="reg-redhat"
            echo -e "  - name: reg-svc"
            echo -e "    remoteurl: https://registry.svc.ci.openshift.org"
            echo -e "    username: '"$my_login"'"
            echo -e "    password: '"$my_pwd"'"
            echo -e "    port: 5005"
	else
	    name="registry"
	fi

    echo -e "  - name: ${name}"
    echo -e "    remoteurl: '"https://${my_url}"'"
    echo -e "    username: '"$my_login"'"
    echo -e "    password: '"$my_pwd"'"
    echo -e "    port: '"$port_num"'"
	let "port_num+=1"
done

exit 0
