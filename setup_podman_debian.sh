#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load functions
source functions.sh

# Exit in case of error
#set -e

# Setup storage
setup_storage() {
    local lpath=$1
}

# Setup Mountpoint
setup_mountpoint() {
    local lpath=$1
}

# Umount if mounted
umount_if_mounted() {
    local mp=$1

    if mountpoint -q "${mp}"
    then
	umount ${mp}
    fi
}

# List subuid / subgid
list_subuid_subgid() {
     local SUBUID=/etc/subuid
     local SUBGID=/etc/subgid

     for i in $SUBUID $SUBGID; do [[ -f "$i" ]] || { echo "ERROR: $i does not exist, but is required."; exit 1; }; done
     [[ -n "$1" ]] && USERS=$1 || USERS=$(awk -F : '{x=x " " $1} END{print x}' $SUBUID)
     for i in $USERS; do
        awk -F : "\$1 ~ /$i/ {printf(\"%-16s sub-UIDs: %6d..%6d (%6d)\", \$1 \",\", \$2, \$2+\$3, \$3)}" $SUBUID
        awk -F : "\$1 ~ /$i/ {printf(\", sub-GIDs: %6d..%6d (%6d)\", \$2, \$2+\$3, \$3)}" $SUBGID
        echo ""
     done
}

# Get Homedir
get_homedir() {
   local user=$1

   # Get homedir
   local homedir=$(getent passwd "$user" | cut -d: -f6)

   # Return result
   echo $homedir
}

# Generate next subuid
#generate_next_subuid()

# Define user
# User name
user=${1:-'podman'}

# Mode (zfs / zvol / dir)
mode=${2:-'zfs'}

# Get homedir
homedir=$(get_homedir "$user")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "$user")

# Storage Path
if [[ "$mode" == "dir" ]]
then
   storage=${3:-'/home/podman/containers'}
elif [[ "$mode" == "zfs" ]]
then
   storage=${3:-'zdata/PODMAN'}
elif [[ "$mode" == "zvol" ]]
then
   storage=${3:-'zdata/PODMAN'}
else
   echo "Storage mode <$mode> NOT supported. Aborting !"
   exit 2
fi

# ZVOL FS (if type=zfs)
#fs=${4:-'ext4'}

# Define datasets
datasets=()
datasets+=("BUILD")
datasets+=("CERTIFICATES")
datasets+=("COMPOSE")
datasets+=("CONFIG")
datasets+=("LOG")
datasets+=("ROOT")
datasets+=("DATA")
datasets+=("IMAGES")
datasets+=("STORAGE")
datasets+=("VOLUMES")
datasets+=("CACHE")
datasets+=("LOCAL")
datasets+=("SECRETS")


# Define ZVOL sizes in GB if applicable
# Be VERY generous with the allocations since no reservation of space is made
zsizes=()
zsizes+=("128G") # BUILD
zsizes+=("16G")  # CERTIFICATES
zsizes+=("16G")  # COMPOSE
zsizes+=("16G")  # CONFIG
zsizes+=("128G") # LOG
zsizes+=("128G") # ROOT
zsizes+=("256G") # DATA
zsizes+=("128G") # IMAGES
zsizes+=("256G") # STORAGE
zsizes+=("256G") # VOLUMES
zsizes+=("128G") # CACHE
zsizes+=("128G") # LOCAL
zsizes+=("128G") # SECRETS

# Setup container user
touch /etc/{subgid,subuid}
useradd -c “Podman” -s /bin/bash $user
passwd -d $user
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $user
passwd $user

nano /etc/subuid
nano /etc/subgid

if [ "$mode" == "zvol"  ]
then
    # Create Root storage
    zfs create -o compression=lz4 -o canmount=on ${storage}

    # Allow over-subscribind in case of ZVOL
    zfs set refreservation=none ${storage}
elif [ "$mode" == "zfs"  ]
then
    # Create Root storage
    zfs create -o compression=lz4 -o canmount=on ${storage}

    # Enable mounting of ZFS datasets
    zfs set canmount=on ${storage}
fi

# Setup FSTAB
echo "# ${user} BIND Mounts" >> /etc/fstab

if [ "$mode" == "zfs" ] || [ "$mode" == "zvol" ]
then
    echo "/${storage}/CONFIG /home/${user}/.config/containers none defaults,rbind 0 0" >> /etc/fstab
else
    echo "/home/${user}/containers/config /home/${user}/.config/containers none defaults,rbind 0 0" >> /etc/fstab
fi


mkdir -p "/home/${user}"
chattr -i "/home/${user}"
mkdir -p "/home/${user}/.config"
mkdir -p "/home/${user}/.config/containers"
mkdir -p "/home/${user}/.config/systemd"

# Ensure proper permissions for config folder
chown -R $user:$user /home/${user}/.config/containers

# Chattr .config/containers directory
chattr +i /home/${user}/.config/containers

# Create Datasets
for dataset in "${datasets[@]}"
do
	# Convert dataset name to lowercase mountpoint
	lname=${dataset,,}

        # Get name
        name="${storage}/${dataset}"

	# Create storage for image directory
	mkdir -p /home/${user}/${lname}/
	umount_if_mounted /home/${user}/${lname}/
	chattr -i /home/${user}/${lname}/
	chown -R $user:$user /home/${user}/${lname}/

	if [ "$mode" == "zfs"  ]
	then
	     # Ensure that mountpoint cannot contain files UNLESS dataset is mounted (user folder)
             chattr +i /home/${user}/${lname}/

	     # Ensure that mountpoint cannot contain files UNLESS dataset is mounted (pool folder)
             chattr +i "/${name}"

	     # Create dataset
	     zfs create -o compression=lz4 ${name}

	     # Add FSTAB entry
	     echo "/${name} /home/${user}/${lname} none defaults,rbind 0 0" >> /etc/fstab

             # Mount dataset
             zfs mount ${name}

	     # Wait a bit
	     sleep 1
        elif [ "$mode" == "zvol" ]
	then
	     # Ensure that mountpoint cannot contain files UNLESS dataset is mounted (user folder)
             chattr +i /home/${user}/${lname}/

	     # Get ZVOL size
             zsize="${zsizes[$counter]}"

	     # Create ZVOL
	     zfs create -s -V ${zsize} ${name}

	     # Create EXT4 Filesystem
             mkfs.ext4 /dev/zvol/${name}

	     # Wait a bit
	     sleep 1

	     # Add FSTAB entry
             echo "/dev/zvol/${name} /home/${user}/${lname} ext4 defaults,nofail,x-systemd.automount 0 0" >> /etc/fstab
        elif [ "$mode" == "dir" ]
	then
	     # Ensure that mountpoint can contain files since nothing will be mounted there in this mode (user folder)
             chattr -i /home/${user}/${lname}/

	else
	     echo "MODE is invalid. It should either be <zfs> or <zvol>. Current value is <$mode>"
	     echo "Aborting ..."
	     exit;
	fi

	# Reload systemd to make use of new FSTAB
	systemctl daemon-reload

	# Mount according to FSTAB
        if [ "$mode" == "zfs" ] || [ "$mode" == "zvol" ]
        then
	    mount /home/${user}/${lname}/
        fi

	# Ensure proper permissions
	chown -R $user:$user /home/${user}/${lname}/

        # Increment counter
        counter=$((counter+1))
done

# Create symbolic links for "legacy" versions of podmans (e.g. not supporting "volumepath" or "imagestore" configuration directives)
rm -f /home/${user}/storage/volumes
ln -s /home/${user}/volumes /home/${user}/storage/volumes
chown $user:$user /home/${user}/storage/volumes

# Save Current Path
scriptspath=$(pwd)

# Install requirements
apt install --yes sudo

# Enable Backports Repository
# Copy Debian Backports Repository Configuration
cp repositories/debian/bookworm/sources.list.d/debian-backports.list /etc/apt/sources.list.d/debian-backports.list

# Install podman
apt -y install podman

# Install podman-compose
apt -y install python3 python3-pip
#pip3 install podman-compose # Use latest version
#pip3 install https://github.com/containers/podman-compose/archive/refs/tags/v0.1.10.tar.gz # Use legacy version

# Allow unprivileged ports <1024 for rootless install
echo "net.ipv4.ip_unprivileged_port_start=80" >> /etc/sysctl.conf

# Allow unprivileged network access
echo "kernel.unprivileged_userns_clone=1" >> /etc/sysctl.d/userns.conf

# Enable CGROUPS v2
# For Rock 5B SBC needs to be manually configured in /boot/mk_extlinux script
echo "Please add <systemd.unified_cgroup_hierarchy=1> to /etc/default/kernel-cmdline or /etc/default/grub"
read -p "Press ENTER once ready" confirmation

if [[ -f "/etc/default/grub" ]]; then
    nano /etc/default/grub
    update-grub
else
    nano /etc/default/kernel-cmdline
fi

# Automatically mount ZFS datasets
zfs mount -a
sleep 2

# Automatically bind-mount remaining datasets
mount -a

# Create folder for running processes
userid=$(id -u $user)
mkdir -p /var/run/user/${userid}
chown -R $user:$user /var/run/user/${userid}
#su $user

# Populate config directory
mkdir -p /home/${user}/.config/containers
cd /home/${user}/.config/containers
wget https://src.fedoraproject.org/rpms/containers-common/raw/main/f/storage.conf -O storage.conf
wget https://src.fedoraproject.org/rpms/containers-common/raw/main/f/registries.conf -O registries.conf
wget https://src.fedoraproject.org/rpms/containers-common/raw/main/f/default-policy.json -O default-policy.json

# Setup folders and set correct permissions
chown -R $user:$user /home/$user

# Set
echo "export XDG_RUNTIME_DIR=/run/user/${userid}" >> /home/$user/.bashrc
echo "export XDG_RUNTIME_DIR=/run/user/${userid}" >> /home/$user/.bash_profile

# Change some configuration
sed -Ei "s|^#? ?runroot = \".*\"|runroot = \"/run/user/${userid}\"|g" storage.conf
sed -Ei "s|^#? ?graphroot = \".*\"|graphroot = \"/home/${user}/storage\"|g" storage.conf
sed -Ei "s|^#? ?rootless_storage_path = \".*\"|rootless_storage_path = \"/home/${user}/storage\"|g" storage.conf
sed -Ei "s|^#? ?imagestore = \".*\"|imagestore = \"/home/${user}/images\"|g" storage.conf
sed -Ei "s|^#? ?volumepath = \".*\"|volumepath = \"/home/${user}/volumes\"|g" storage.conf
sed -Ei "s|^#? ?mount_program = \".*\"|mount_program = \"/usr/bin/fuse-overlayfs\"|g" storage.conf

# Enable cgroups v2
#sed -i 's/#CGROUP_MODE=hybrid/CGROUP_MODE=hybrid/g' /etc/rc.conf

# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime

# Setup default Timeout settings for Systemd
sed -Ei "s|^#DefaultTimeoutStartSec\s*=.*|DefaultTimeoutStartSec=15s|g" /etc/systemd/system.conf
sed -Ei "s|^#DefaultTimeoutStopSec\s*=.*|DefaultTimeoutStopSec=15s|g" /etc/systemd/system.conf
sed -Ei "s|^#DefaultDeviceTimeoutSec\s*=.*|DefaultDeviceTimeoutSec=15s|g" /etc/systemd/system.conf
sed -Ei "s|^#DefaultStartLimitIntervalSec\s*=.*|DefaultStartLimitIntervalSec=10s|g" /etc/systemd/system.conf
sed -Ei "s|^#DefaultStartLimitBurst\s*=.*|DefaultStartLimitBurst=500|g" /etc/systemd/system.conf

sed -Ei "s|^#DefaultTimeoutStartSec\s*=.*|DefaultTimeoutStartSec=15s|g" /etc/systemd/user.conf
sed -Ei "s|^#DefaultTimeoutStopSec\s*=.*|DefaultTimeoutStopSec=15s|g" /etc/systemd/user.conf
sed -Ei "s|^#DefaultDeviceTimeoutSec\s*=.*|DefaultDeviceTimeoutSec=15s|g" /etc/systemd/user.conf
sed -Ei "s|^#DefaultStartLimitIntervalSec\s*=.*|DefaultStartLimitIntervalSec=10s|g" /etc/systemd/user.conf
sed -Ei "s|^#DefaultStartLimitBurst\s*=.*|DefaultStartLimitBurst=500|g" /etc/systemd/user.conf

# Enable lingering sessions
loginctl enable-linger ${userid}

# Upgrade other parts of the system
apt --yes dist-upgrade

# Rebuild initramfs
update-initramfs -k all  -u

# Setup Systemd
# Source: https://salsa.debian.org/debian/libpod/-/blob/debian/sid/contrib/systemd/README.md#user-podman-service-run-as-given-user-aka-rootless
# Need to execute as podman user
# Setup files
sudo -u $user mkdir -p /home/$user/.config/systemd/user
sudo -u $user cp /lib/systemd/user/podman.service /home/$user/.config/systemd/user/
sudo -u $user cp /lib/systemd/user/podman.socket /home/$user/.config/systemd/user/
sudo -u $user cp /lib/systemd/user/podman-auto-update.timer /home/$user/.config/systemd/user/
sudo -u $user cp /lib/systemd/user/podman-auto-update.service /home/$user/.config/systemd/user/
sudo -u $user cp /lib/systemd/user/podman-restart.service /home/$user/.config/systemd/user/

# Install additionnal packages
apt --yes install uidmap fuse-overlayfs slirp4netns

# Disable root-level services
systemctl disable podman-restart.service
systemctl disable podman.socket
systemctl disable podman-auto-update

# Enable user-level services
systemd_enable_run "$user" "podman.socket"
systemd_enable_run "$user" "podman.service"
systemd_enable_run "$user" "podman-restart.service"
systemd_enable_run "$user" "podman-auto-update.service"
systemd_status "$user" "podman.socket podman.service podman-restart.service podman-auto-update.service"
systemd_reexec
systemd_reload

# https://github.com/containers/podman/issues/3024#issuecomment-1742105831 ,  https://github.com/containers/podman/issues/3024#issuecomment-1762708730
mkdir -p /etc/systemd/system/user@.service.d
cd /etc/systemd/system/user@.service.d
echo "[Service]" > override.conf
echo "OOMScoreAdjust=" >> override.conf

# Prevent Systemd from auto restarting Podman Containers too quickly and timing out
cd $scriptspath
mkdir -p /etc/systemd/user.conf.d/
cp systemd/conf/podman.systemd.conf /etc/systemd/user.conf.d/podman.conf

# Install podman-compose
aptitude -y install podman-compose

# Enable rc.local service and make sure ZFS dataset are mounted BEFORE everything else
./enable_rc_local.sh

# Setup CRON/Systemd to automatically generate updated Systemd Service files
./setup_podman_autostart_service.sh

# Setup CRON/Systemd to automatically detect traefik changes and restart traefik to apply them
./setup_podman_traefik_monitor_service.sh

# Setup CRON/Systemd to automatically install images updates
./setup_podman_autoupdate_service.sh

# Setup CRON/Systemd job to automatically update the Podman Tools (run git pull from toolpath)
./setup_tools_autoupdate_service.sh

# Increase Limits on Maximum Number of Open Files
sudo sh -c "echo '* soft     nofile         65535
* hard     nofile         65535' > /etc/security/limits.d/30-max-number-open-files.conf"
