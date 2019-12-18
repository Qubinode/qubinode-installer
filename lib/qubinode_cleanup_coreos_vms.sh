#!/bin/bash

function cleanup(){
    #clean up
    sudo virsh destroy bootstrap; sudo virsh undefine bootstrap --remove-all-storage

    for i in {0..2}
    do
        sudo virsh destroy master-${i};sudo virsh undefine master-${i} --remove-all-storage
    done

    for i in {0..1}
    do
        sudo virsh destroy compute-${i};sudo virsh undefine compute-${i} --remove-all-storage
    done
}

cleanup
