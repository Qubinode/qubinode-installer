# Home Assistant 

This will deploy [home-assistant.io](https://www.home-assistant.io/) on your machine. 

Open source home automation that puts local control and privacy first. Powered by a worldwide community of tinkerers and DIY enthusiasts.

## Prerequises 
* Persistent Volume claim
* A running openshift cluster
* OpenShift admin access

**Create Project**
```
$ oc new-project home-assistant
```

**Create persistent volume claim yaml file**
```
$ vi home-assistant-pvc.yml

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: home-assistant-mount
  namespace: home-assistant
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

```

**Create the claim** 
```
$ oc create -f home-assistant-pvc.yml
```

**Give root privlages to container** 
```
$  oc adm policy add-scc-to-user anyuid -z default
```

**Create home assistant deployment yaml** 
```
$ vi home-assistant-deployment.yaml
kind: DeploymentConfig
apiVersion: apps.openshift.io/v1
metadata:
  resourceVersion: '461920'
  name: home-assistant
  namespace: home-assistant
  labels:
    app: home-assistant
    app.kubernetes.io/component: home-assistant
    app.kubernetes.io/instance: home-assistant
    app.kubernetes.io/part-of: home-assistant-app
spec:
  strategy:
    type: Rolling
    rollingParams:
      updatePeriodSeconds: 1
      intervalSeconds: 1
      timeoutSeconds: 600
      maxUnavailable: 25%
      maxSurge: 25%
    resources: {}
    activeDeadlineSeconds: 21600
  triggers:
    - type: ImageChange
      imageChangeParams:
        automatic: true
        containerNames:
          - home-assistant
        from:
          kind: ImageStreamTag
          namespace: home-assistant
          name: 'home-assistant:stable'
        lastTriggeredImage: >-
          homeassistant/home-assistant@sha256:d8a9cfa40e380f616c87c974bbc03e921f85181b31afdf8e9802df5704dd057d
    - type: ConfigChange
  replicas: 1
  revisionHistoryLimit: 10
  test: false
  selector:
    app: home-assistant
    deploymentconfig: home-assistant
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: home-assistant
        deploymentconfig: home-assistant
    spec:
      volumes:
        - name: mountpoint
          persistentVolumeClaim:
            claimName: home-assistant-mount
      containers:
        - name: home-assistant
          image: >-
            homeassistant/home-assistant@sha256:d8a9cfa40e380f616c87c974bbc03e921f85181b31afdf8e9802df5704dd057d
          ports:
            - containerPort: 8080
              protocol: TCP
          resources: {}
          volumeMounts:
            - name: mountpoint
              mountPath: /config
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      schedulerName: default-scheduler
---
kind: ImageStream
apiVersion: image.openshift.io/v1
metadata:
  name: home-assistant
  namespace: home-assistant
  labels:
    app: home-assistant
    app.kubernetes.io/component: home-assistant
    app.kubernetes.io/instance: home-assistant
    app.kubernetes.io/part-of: home-assistant-app
spec:
  lookupPolicy:
    local: false
  tags:
    - name: stable
      annotations:
        openshift.io/imported-from: 'homeassistant/home-assistant:stable'
      from:
        kind: DockerImage
        name: 'homeassistant/home-assistant:stable'
      importPolicy: {}
      referencePolicy:
        type: Source  
---  
apiVersion: v1
kind: Service
metadata:
  labels:
    app: home-assistant
    app.kubernetes.io/component: home-assistant
    app.kubernetes.io/instance: home-assistant
    app.kubernetes.io/name: ""
    app.kubernetes.io/part-of: home-assistant-app
    app.openshift.io/runtime: ""
    app.openshift.io/runtime-version: stable
  name: home-assistant
  namespace: home-assistant
spec:
  selector:
    app: home-assistant
  ports:
    - name: 8123-tcp
      port: 8123
      protocol: TCP
      targetPort: 8123
      selector:
        app: home-assistant
        deploymentconfig: home-assistant
sessionAffinity: None
type: ClusterIP
status:
loadBalancer: {}
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  creationTimestamp: "2020-04-24T00:07:32Z"
  labels:
    app: home-assistant
    app.kubernetes.io/component: home-assistant
    app.kubernetes.io/instance: home-assistant
    app.kubernetes.io/name: ""
    app.kubernetes.io/part-of: home-assistant-app
    app.openshift.io/runtime: ""
    app.openshift.io/runtime-version: stable
  name: home-assistant
  namespace: home-assistant
spec:
  host: home-assistant-home-assistant.apps.qbn.cloud.PLEASECHANGEME.com
  port:
    targetPort: 8123-tcp
  to:
    kind: Service
    name: home-assistant
    weight: 100
  wildcardPolicy: None

```

**Change the host to your domain**
```
spec:
  host: home-assistant-home-assistant.apps.qbn.cloud.PLEASECHANGEME.com
  to:
    kind: Service
    name: home-assistant
    weight: 100
  port:
    targetPort: 8123-tcp
  wildcardPolicy: None
```

**Create home assistant deployment**
```
$ oc create -f home-assistant-deployment.yaml
```

**get deployment status**
```
$ oc get pods
```

**get route**
```
$ oc get route 
```

Have Fun :)

### Link
* https://www.home-assistant.io/
* [Forum](https://community.home-assistant.io/)
* [Discord Chat Server](https://discord.gg/c5DvZ4e) for general Home Assistant discussions and questions.
* Follow us on [Twitter](https://twitter.com/home_assistant), use [@home_assistant](https://twitter.com/home_assistant)
* Join the [Facebook community](https://www.facebook.com/homeassistantio)
* Join the Reddit in [/r/homeassistant](https://reddit.com/r/homeassistant)