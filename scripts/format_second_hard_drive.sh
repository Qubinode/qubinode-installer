#/bin/bash
# Author: Tosin Akinosho

if [[ -z $DRIVE ]]; then
  #statements
fi

DRIVE=nvme0n1
#format mount point
mkfs.ext4 /dev/$DRIVE 2>/dev/null
#create dirctory
mkdir -p /kvm/

#mount for start up
echo '/dev/'${DRIVE}' /kvm/ auto noatime,noexec,nodiratime 0 0' >> /etc/fstab
mount -a /dev/$DRIVE /kvm/
mkdir -p /kvm/kvmdata
mkdir -p /kvm/kvmimages
