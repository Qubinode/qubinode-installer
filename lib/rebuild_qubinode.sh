#!/bin/bash

rebuild_qubinode () {
    teardown_idm
    teardown_ocp3
    teardown_ocp4
    teardown_tower
    teardown_satellite
    forceVMteardown
    removeStorage
    
    printf "%s\n" " System is ready for rebuild"
    exit 0
}
