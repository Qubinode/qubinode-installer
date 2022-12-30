
 sudo pvcreate /dev/sdb /dev/sdc /dev/sdd
 vgcreate vg_qubi /dev/sdb1 /dev/sdc1 /dev/sdd1
 lvcreate -L8T -n vg_qubi-lv_qubi_images vg_qubi 
 mkfs.ext4 /dev/vg_qubi/vg_qubi-lv_qubi_images
 mkdir -p /var/lib/libvirt/images
 mount  /dev/vg_qubi/vg_qubi-lv_qubi_images /var/lib/libvirt/images
 echo "/dev/vg_qubi/vg_qubi-lv_qubi_images   /var/lib/libvirt/images  ext4   defaults    0   0" >>  /etc/fstab