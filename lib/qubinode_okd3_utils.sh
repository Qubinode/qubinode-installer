#!/bin/bash
function okd3_deployment () {
    # This function is called by the menu option -p ocp3
    # It's the primary function that starts the deployment
    # of the OCP3 cluster.

    # Set global product variable to OpenShift 3
    # This variable needs to be set before all else
    openshift_product=okd3

    # Load all global openshift variable
    set_openshift_production_variables

    # Deploy OpenShift Nodes if they are not deployed
    ping_openshift3_nodes

    # Check if the OCP3 cluster is already deployed
    # Check if the cluster is reponding
    #WEBCONSOLE_STATUS=$(check_webconsole_status_ocp3)
    if [[ "A${IS_OPENSHIFT3_NODES}" != "Ayes" ]]
    then
        deploy_openshift3_nodes
    fi

    # Check if the cluster is reponding
    WEBCONSOLE_STATUS=$(check_webconsole_status_ocp3)
    if [[ $WEBCONSOLE_STATUS -ne 200 ]]
    then
        #ask_user_which_openshift_product #this function should be deleted
        #are_openshift3_nodes_available  #this function should be deleted
        qubinode_deploy_openshift3

        # Wait for OpenShift Console to come up
        sleep 45s

        # Ensure the qubinode user is added to openshift
        ensure_ocp_default_user
    else
        # Ensure the qubinode user is added to openshift
        ensure_ocp_default_user

        # Report on OpenShift Installation
        openshift3_installation_msg
    fi
}
