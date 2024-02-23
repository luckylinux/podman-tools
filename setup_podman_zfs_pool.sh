#zpool create -f -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O mountpoint=/zdata zdata /dev/disk/by-partlabel/PODMAN
zpool create -f -o ashift=12 -O atime=off -O canmount=off -O compression=off -O mountpoint=/zdata zdata /dev/disk/by-partlabel/PODMAN
