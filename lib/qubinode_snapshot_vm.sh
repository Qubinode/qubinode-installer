#!/bin/bash

function createmenu () {
    select selected_option; do # in "$@" is the default
        if [ "$REPLY" -eq "$REPLY" 2>/dev/null ]
        then
            if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $(($#)) ]; then
                break;
            else
                echo "    Please make a vaild selection (1-$#)."
            fi
         else
            echo "    Please make a vaild selection (1-$#)."
         fi
    done
}

declare -a ALL_VMS=()
mapfile -t ALL_VMS < <(sudo virsh list --name|egrep [a-z])
echo "Which VM would you like to snapshot? "
createmenu "${ALL_VMS[@]}"
VM_NAME=($(echo "${selected_option}"))


# Get vda disk
SNAPSHOTS_DIR=/var/lib/libvirt/images/snapshots
VM_BACKUP_DIR=/var/lib/libvirt/images/backups

test -d ${SNAPSHOTS_DIR} || sudo mkdir -p ${SNAPSHOTS_DIR}
test -d ${VM_BACKUP_DIR} || sudo mkdir -p ${VM_BACKUP_DIR}
DISKS_PATH=$(sudo virsh domblklist ${VM_NAME}| awk -e '$1 ~ /vd[a-z]/ {print $2}')
VM_DISK_DEVICES=$(sudo virsh domblklist ${VM_NAME}| awk -e '$1 ~ /vd[a-z]/ {print $1}')

DISK_DEVICES=( $VM_DISK_DEVICES )

## create an external snapshot and generate a new active image called overlay.qcow2:

for disk in ${DISK_DEVICES[@]}
do
    SNAPSHOT_DISK_TMP_NAME="${SNAPSHOTS_DIR}/${VM_NAME}_${disk}_overlay_0.qcow2"

    if [ -e $SNAPSHOT_DISK_TMP_NAME ]
    then
        i=0
        SS_DISK_NAME="${SNAPSHOT_DISK_TMP_NAME}"
        until [ ! -f ${SS_DISK_NAME} ]
        do
            let i++
            SS_DISK_NAME="${SNAPSHOTS_DIR}/${VM_NAME}_${disk}_overlay_${i}.qcow2"
        done
        SNAPSHOT_DISK_NAME=${SS_DISK_NAME}
        VM_SNAPSHOT_NAME="${VM_NAME}_snap_${i}"
	SUFFIX="${i}"
    else
        SNAPSHOT_DISK_NAME="${SNAPSHOT_DISK_TMP_NAME}"
        VM_SNAPSHOT_NAME="${VM_NAME}_snap_0"
	SUFFIX="0"
    fi

    SOURCE_DISK_PATH=$(sudo virsh domblklist ${VM_NAME}| awk -v var=$disk -e '$0 ~ var {print $2}')

    sudo virsh snapshot-create-as --domain ${VM_NAME} ${VM_SNAPSHOT_NAME} --diskspec ${disk},file=${SNAPSHOT_DISK_NAME} --disk-only --atomic


    if sudo virsh domblklist ${VM_NAME} | grep -q $SNAPSHOT_DISK_NAME
    then
	DISK_NAME=$(basename $SOURCE_DISK_PATH)
        sudo cp $SOURCE_DISK_PATH $VM_BACKUP_DIR/${DISK_NAME}.${SUFFIX}
        sudo virsh blockcommit ${VM_NAME} ${disk} --active --verbose --pivot
    fi

    if sudo virsh domblklist ${VM_NAME} | grep -q $SOURCE_DISK_PATH
    then
        sudo virsh snapshot-delete ${VM_NAME} --metadata --current
        sudo rm -f ${SNAPSHOTS_DIR}/${SNAPSHOT_DISK_NAME}
        echo "Snapshot succesfull"
    fi
done

exit 0
