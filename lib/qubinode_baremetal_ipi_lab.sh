#!/bin/bash

setup_variables
product_in_use=baremetal_ipi_lab
source "${project_dir}/lib/qubinode_utils.sh"


function qubinode_ipi_lab_maintenance () {
    case ${product_maintenance} in
       configure_latest_ocp)
	        configure_latest_ocp
            ;;
       configure_disconnected_repo)
	        configure_disconnected_repo
            ;;
       install_packages)
	        install_packages
            ;;
       *)
           echo "No arguement was passed"
           ;;
    esac
}

function install_packages(){
  sudo dnf -y install podman httpd httpd-tools
}
function configure_disconnected_repo(){
  sudo mkdir -p /nfs/registry/{auth,certs,data}
  sudo openssl req -newkey rsa:4096 -nodes -sha256 \
    -keyout /nfs/registry/certs/domain.key -x509 -days 365 -out /nfs/registry/certs/domain.crt \
    -subj "/C=US/ST=NorthCarolina/L=Raleigh/O=Red Hat/OU=Marketing/CN=provision.$GUID.dynamic.opentlc.com"

  sudo cp /nfs/registry/certs/domain.crt $HOME/scripts/domain.crt
  sudo chown lab-user $HOME/scripts/domain.crt
  sudo cp /nfs/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
  sudo update-ca-trust extract
  sudo htpasswd -bBc /nfs/registry/auth/htpasswd dummy dummy
  sudo podman create --name poc-registry --net host -p 5000:5000 \
      -v /nfs/registry/data:/var/lib/registry:z -v /nfs/registry/auth:/auth:z \
      -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
      -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
      -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /nfs/registry/certs:/certs:z \
      -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
      -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key docker.io/library/registry:2
  sudo podman start poc-registry
  sudo podman ps
  curl -u dummy:dummy -k \
      https://provision.$GUID.dynamic.opentlc.com:5000/v2/_catalog
  echo "Configure a Disconnected Registry and Red Hat Enterprise Linux CoreOS Cache"
  printf "%s\n" " ${red}Configure a Disconnected Registry and Red Hat Enterprise Linux CoreOS Cache${end}"
  printf "%s\n" "Link: https://github.com/RHFieldProductManagement/baremetal-ipi-lab/blob/master/03-configure-local-registry-cache.md"
}

function configure_latest_ocp(){
  echo "Configure Latest OCP"
  printf "%s\n" " ${red}Configure Latest OCP${end}"
  sudo rm -rf /usr/local/bin/oc
  curl -OL https://raw.githubusercontent.com/tosin2013/openshift-4-deployment-notes/master/pre-steps/configure-openshift-packages.sh
  chmod +x configure-openshift-packages.sh
  sudo ./configure-openshift-packages.sh -i
  sudo ln /usr/bin/oc /usr/local/bin/oc
  cd /home/lab-user/scripts
  export extract_dir=$(pwd)
  export VERSION=$(oc version  | grep Client | awk '{print $3}')
  echo $VERSION
  oc adm release extract --registry-config "$HOME/pull-secret.json" --command=openshift-baremetal-install --to "${extract_dir}" ${VERSION}
  sudo cp openshift-baremetal-install /usr/local/bin
}

function qubinode_setup_ipilab() {
  printf "%s\n" "   ${blu}Configuring ipilab${end}"
  printf "%s\n" "   ${blu}Link: https://github.com/RHFieldProductManagement/baremetal-ipi-lab${end}"
}
