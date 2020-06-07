No available subscription pools were found matching the expression:

 Red Hat OpenShift Container Platform

Please make sure you have a subscription to Red Hat OpenShift Container Platform
before trying the installation again.

$ sudo subscription-manager status
if subscription-manager status is Current
$ sudo subscription-manager list --available --matches '*OpenShift*'

In the output for the previous command, find the pool ID for an OpenShift Container Platform subscription and attach it:
$ sudo subscription-manager attach --pool=<pool_id>
$ ./qubinode-installer  -m rhsm -p ocp

If subscription-manager status is not Current

You can also try delete the subscription from the system via the customer portal, then
run qubinode-installer -m rhsm again. This can be done by:

Log into the portal here: https://access.redhat.com/management/systems
Find your system, and click on it
Click the subscriptions tab
Click remove

run the following command:

$ sudo subscription-manager  clean
$ sudo subscription-manager refresh
$ ./qubinode-installer  -m rhsm -p <product>

e.g. -installer  -m rhsm -p ocp4


Otherwise you may want to try deploying okd instead
