#!/usr/bin/env bash
set -euo pipefail
if [ ${QUBINODE} == "true" ];
then
	PVC_PATH="/var/lib/libvirt/images/"
else 
	PVC_PATH="/"
fi 



#clean before
> /etc/exports
rm -fr ${PVC_PATH}pv*

# install the nfs
export KUBECONFIG=/root/.kcli/clusters/${OC_CLUSTER_NAME}/auth/kubeconfig
export PRIMARY_IP=192.168.150.1
dnf -y install nfs-utils
systemctl enable --now nfs-server
export MODE="ReadWriteOnce"
for i in $(seq 1 10); do
	export PV=pv$(printf "%03d" ${i})
	mkdir ${PVC_PATH}${PV} ||true
	echo "${PVC_PATH}${PV} *(rw,no_root_squash)" >>/etc/exports
	chcon -t svirt_sandbox_file_t ${PVC_PATH}${PV}
	chmod 777 ${PVC_PATH}${PV}
	[ "${i}" -gt "10" ] && export MODE="ReadWriteMany"
	if [ ${QUBINODE} == "true" ];
	then
		envsubst <./nfs-qubinode.yml | oc apply -f -
	else 
		envsubst <./nfs.yml | oc apply -f -
	fi 
	
done
exportfs -r

firewall-cmd --zone=libvirt --permanent --add-service=nfs
firewall-cmd --zone=libvirt --permanent --add-service=mountd
firewall-cmd --zone=libvirt --permanent --add-service=rpc-bind
firewall-cmd --reload