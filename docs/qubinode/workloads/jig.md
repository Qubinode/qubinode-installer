# Jig - Workshop Service Worker

This is a PHP application built to provide advanced functionality to Red Hat workshops.  [Click here to contribute](https://github.com/kenmoini/jig)  

## Qubinode Requirements
* Local storage with at 10Gigs os storage `this can be changed if you would like`

### Install kustomize
[kustomize](https://kubernetes-sigs.github.io/kustomize/installation/)
```bash
$ curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
$ sudo mv kustomize /usr/local/bin/
```

### Clone repo 
```
git clone https://github.com/kenmoini/jig.git
```
### cd into jig folder 
```
cd jig
```

### Deploy to OpenShift using kustomize 

**Create jig-workshop-worker project**
```bash
oc new-project  jig-workshop-worker
```

**Deploy mysql database**
```bash
oc process -f deploy/overlay/openshift/mysql-template.yaml  --param=VOLUME_CAPACITY=10Gi | oc create -f -  -n jig-workshop-worker
```

**Optional update patch-env.yaml**  
*This will update the configmap for your deployment*
```
vim deploy/overlay/openshift/patch-env.yaml
```

**Validate Configs**
```bash
kustomize build deploy/overlay/openshift/ | less
```

**Deploy application**
```bash
kustomize build deploy/overlay/openshift/ | oc create -f -
```

**Get admin password**
```bash
oc exec $(oc get pods -n jig-workshop-worker | grep jig-workshop-worker- | awk '{print $1}')  -- cat storage/app/generated_admin_password
```

**Admin username**
* `admin@admin.com`

**To delete deployment**
```bash
oc process -f deploy/overlay/openshift/mysql-template.yaml  --param=VOLUME_CAPACITY=10Gi | oc delete -f -  -n jig-workshop-worker
kustomize build deploy/overlay/openshift/ | oc delete -f -
oc project delete  jig-workshop-worker
```
