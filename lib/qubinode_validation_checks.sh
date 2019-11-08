function list_openshift_nodes() {
  if sudo virsh list|grep -E 'master|node|infra'
  then
      echo "OpenShift VMs exist"
      sudo virsh list
  else
      product_opt=$(awk '/^product:/ {print $2}' "${project_dir}/playbooks/vars/all.yml")
      echo "Please run ./qubinode-installer -p ${product_opt} -m deploy_nodes"
      exit 1
  fi
}
