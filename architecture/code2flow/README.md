# The qubinode-installer code flowcharts

You can plug the below code into [code2flow](https://code2flow.com/app) and it will render flowcharts of the code.

## High level flow of the qubinode-installer ocp3/okd options.

Copy and paste the below code to code2flow to generate the flowchart.

```
  // menu options are called from **qubinode_menu_options.sh**
qubinode-installer;
branch(install) [-p ocp3] {
    // these functions are all in qubinode_openshift3.sh
  [function]
  openshift_enterprise_deployment;
  [function]
  set_openshift_production_variables;
  [function]
  report_on_openshift3_installation;
  if(Is OCP3 Cluster Up?){
    [function]
    openshift3_installation_msg;
  } else {
      [function]
      ask_user_which_openshift_product;
      [function]
      are_openshift_nodes_available;
      [function]
      qubinode_deploy_openshift;
      [function]
      openshift3_installation_msg;
  }
}
branch(teardown) [-p ocp3 -d] {
  // these functions are all in qubinode_openshift3.sh
  [function]
  qubinode_teardown_openshift;
  openshift3_variables;
  if(Confirm delete of Cluster VMs?){
    if VMs running? {
      [playbook]
      openshift3_nodes_dns_records.yml;
    } else {
      return;
    }
    [playbook]
    openshift3_deploy_nodes.yml;
    [function]
    qubinode_teardown_cleanup;
  } else {
      No changes;
  }
}
branch(maintenance) [-p ocp3 -m] {
    // these functions are all in qubinode_openshift3.sh
  [function]
  openshift3_server_maintenance;
  switch(Maintenance Options) {
    case diag:
      oadm diagnostics;
      break;
    case smoketest:
      [function]
      get_admin_user_password;
      [script]
      openshift-smoke-test.sh;
      break;
    case shutdown:
      [function]
      openshift3_cluster_shutdown;
      break;
    case startup:
      [function]
      openshift3_cluster_startup;
      break;
    case checkcluster:
      [script]
      CHECK_STATE_CMD;
      break;
  }
}
```


## qubinode-installer -p ocp3

Copy and paste the below code to code2flow to generate the flowchart.

```
function openshift_enterprise_deployment {
  set_openshift_production_variables;
  call report_on_openshift3_installation;
  if(Is the Cluster up?) {
    openshift3_installation_msg;
  } else {
    call ask_user_which_openshift_product;
    call are_openshift_nodes_available;
    call qubinode_deploy_openshift;
    openshift3_installation_msg
  }
}

function report_on_openshift3_installation {
  are_openshift_nodes_available;
  if(Total Nodes?) {
    **Get OCP Cluster**;
    return OCP_STATUS;
  } else {
    set openshift variables;
  }
  if(Teardown){
    if(openshift_auto_install) {
      set_openshift_production_variables
    } else {
      if(yes) {
        accept_ocp3_build;
        set_openshift_production_variables;
      { else {
        ask_user_which_openshift_product
      }
  }
}

function ask_user_which_openshift_product {
  if(openshift_product variable not set) {
    select ocp3 version;
    set openshift_product variable;
    set openshift_product;
  }
}

function are_openshift_nodes_available {
  ping_nodes;
  if(not correct number of nodes) {
    qubinode_openshift_nodes;
    qubinode_openshift3_nodes_postdeployment;
    ping_nodes;
    if(not correct number of nodes) {
      Abort;
    }
  } else {
    if(not correct number of masters) {
      Abort;
    } else {
      build list of all nodes;
      qubinode_openshift3_nodes_postdeployment;
    }
  }
}

function qubinode_deploy_openshift {
  setup_variables;
  openshift3_variables;
  qubinode_rhsm_register;
  validate_openshift_pool_id;
  check_openshift3_size_yml;
  if(openshift_user) {
    [playbook]
    openshift3_setup_deployer_node_playbook
    if(openshift installer) {
      [playbook]
      openshift3_inventory_generator_playbook;
      if(Inventory file exist) {
        [playbook]
        openshift3_pre_deployment_checks_playbook;
        switch(OCP Installation) {
          case ocp3:
            [playbook]
            playbooks/prerequisites.yml;
            [playbook]
            playbooks/deploy_cluster.yml;
            openshift3_installation_msg;
            break;
          case okd3:
            cd homedir/openshift-ansible;
            [playbook]
            playbooks/prerequisites.yml;
            [playbook]
            playbooks/deploy_cluster.yml;
            break;
        }
      } else {
        Exit;
      }
    } else {
      Exit;
    }
  } else {
    Exit;
  }
}

Start;
// menu options are called from **qubinode_menu_options.sh**
qubinode-installer -p ocp3;

// these functions are all in qubinode_openshift3.sh
call openshift_enterprise_deployment;

```
