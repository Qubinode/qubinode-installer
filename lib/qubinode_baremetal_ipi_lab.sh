#!/bin/bash

setup_variables
product_in_use=baremetal_ipi_lab
source "${project_dir}/lib/qubinode_utils.sh"


  RHEL_VERSION=$(get_rhel_version)
  if [[ $RHEL_VERSION == "FEDORA" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.10)/site-packages/kvirt/defaults.py"
  elif [[ $RHEL_VERSION == "RHEL8" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.6)/site-packages/kvirt/defaults.py"
  elif [[ $RHEL_VERSION == "ROCKY8" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.6)/site-packages/kvirt/defaults.py"

  elif [[ $(get_distro) == "centos" ]]; then
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.9)/site-packages/kvirt/defaults.py"
  else 
    defaults_file="/usr/lib/python$(python3 --version | grep -oe 3.9)/site-packages/kvirt/defaults.py"
  fi 


function qubinode_setup_ipi_lab() {
  echo "Configuring ipi lab"
}

```
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
export IRONIC_DATA_DIR=/nfs/ocp/ironic
export IRONIC_IMAGES_DIR="${IRONIC_DATA_DIR}/html/images"
export IRONIC_IMAGE=quay.io/metal3-io/ironic:main
sudo mkdir -p $IRONIC_IMAGES_DIR
sudo chown -R "${USER}:users" "$IRONIC_DATA_DIR"
sudo find $IRONIC_DATA_DIR -type d -print0 | xargs -0 chmod 755
sudo chmod -R +r $IRONIC_DATA_DIR
sudo podman pod create -n ironic-pod
sudo podman run -d --net host --privileged --name httpd --pod ironic-pod \
    -v $IRONIC_DATA_DIR:/shared --entrypoint /bin/runhttpd ${IRONIC_IMAGE}
sudo podman ps
curl http://provision.$GUID.dynamic.opentlc.com/images



cat <<EOF > ~/reg-secret.txt
"provision.$GUID.dynamic.opentlc.com:5000": {
    "email": "dummy@redhat.com",
    "auth": "$(echo -n 'dummy:dummy' | base64 -w0)"
}
EOF
export PULLSECRET=$HOME/pull-secret.json
cp $PULLSECRET $PULLSECRET.orig
cat $PULLSECRET | jq ".auths += {`cat ~/reg-secret.txt`}" > $PULLSECRET
cat $PULLSECRET | tr -d '[:space:]' > tmp-secret
mv -f tmp-secret $PULLSECRET
rm -f ~/reg-secret.txt
sed -i -e 's/^/  /' $(pwd)/domain.crt
echo "additionalTrustBundle: |" >> $HOME/scripts/install-config.yaml
cat $HOME/scripts/domain.crt >> $HOME/scripts/install-config.yaml
sed -i "s/pullSecret:.*/pullSecret: \'$(cat $PULLSECRET)\'/g" \
    $HOME/scripts/install-config.yaml
grep pullSecret install-config.yaml | sed 's/^pullSecret: //' | tr -d \' | jq .



export UPSTREAM_REPO="quay.io/openshift-release-dev/ocp-release:$VERSION-x86_64"
export PULLSECRET=$HOME/pull-secret.json
export LOCAL_REG="provision.$GUID.dynamic.opentlc.com:5000"
export LOCAL_REPO='ocp4/openshift4'
oc adm release mirror -a $PULLSECRET --from=$UPSTREAM_REPO \
    --to-release-image=$LOCAL_REG/$LOCAL_REPO:$VERSION --to=$LOCAL_REG/$LOCAL_REPO
```