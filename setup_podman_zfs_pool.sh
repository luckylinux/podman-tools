# The Disk / Partition mentioned here it's actually a ZFS ZVOL on Proxmox VE passed through the PodmanServer## Virtual Machine
# Thus there is no need to enable compression, as that task is already performed on the host, and would only bring extra performance loss
zpool create -f -o ashift=12 -O atime=off -O canmount=off -O compression=off -O mountpoint=/zdata -o compatibility=openzfs-2.0-linux zdata /dev/disk/by-partlabel/PODMAN
