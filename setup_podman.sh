#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Configuration
# shellcheck source=./config.sh
source ${toolpath}/config.sh

# Load Functions
source ${toolpath}/functions.sh

# Exit in case of error
#set -e

# Get OS Release
get_os_release() {
    # The Distribution can be Detected by looking at the Line starting with ID=...
    # Possible values: ID=fedora, ID=debian, ID=ubuntu, ...
    distribution=$(cat /etc/os-release | grep -Ei "^ID=" | sed -E "s|ID=([a-zA-Z]+?)|\1|")

    # Return Value
    echo $distribution
}

# Setup storage
setup_storage() {
    local lpath=${1}
}

# Setup Mountpoint
setup_mountpoint() {
    local lpath=${1}
}

# Umount if mounted
umount_if_mounted() {
    local mp=${1}

    if mountpoint -q "${mp}"
    then
	umount ${mp}
    fi
}

# Set ZFS Property
set_zfs_property() {
   # Target (ZFS Dataset or ZFS ZVOL) is the First Argument of the Function
   local ltarget="${1}"

   # Property Name is the Second Argument of the Function
   local lpropertyname="${2}"

   # Property Value is the Third Argument of the Function
   local lpropertyvalue="${3}"

   if [[ "${lpropertyvalue}" == "${zfsdefault}" ]]
   then
      # Inherit Property from Parent Dataset or use ZFS Defaults if Parent does NOT have the Property set by the User to a Custom Value
      zfs inherit -S ${lpropertyname} ${ltarget}
   else
      # Set Property
      zfs set ${lpropertyname}=${lpropertyvalue} ${ltarget}
   fi
}

# Generate next subuid
#generate_next_subuid()

# Define user
# User name
export user=${1}
#export user=${1:-'podman'}

if [[ ! -v user ]]
then
    echo "User must be specified"
    exit 11
fi

# Mode (zfs / zvol / dir)
export mode=${2}
#export mode=${2:-'zfs'}

if [[ ! -v mode ]]
then
    echo "Mode must be specified and be one of <dir> or <zfs> or <zvol>"
    exit 12
fi

# Get homedir
homedir=$(get_homedir "${user}")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "${user}")

# Get Distribution OS Release
distribution=$(get_os_release)

# Storage Path
if [[ "${mode}" == "dir" ]]
then
   storage=${3:-"/home/${user}/containers"}
   destination=${storage}
elif [[ "${mode}" == "zfs" ]]
then
   storage=${3:-'zdata/PODMAN'}
   destination=${4:-"/home/${user}/containers"}

   # Ask whether to forcefully DISABLE compression, DISABLE automatic snapshots and ENABLE autotrim
   # Needed for instance when running ZFS on top of (e.g. Proxmox VE Host) ZVOL
   echo -e "Some Settings will need to be double-checked now"
   echo -e "When running Podman on ZFS, it's VERY IMPORTANT that compression/automatic snapshots are ONLY ENABLED if the Disk is a RAW Storage Device (Physical Disk or LUKS/DMCRYPT Device)"
   echo -e "If running ZFS on top of a ZVOL (e.g. in a Proxmox VE Virtual Machine), then:"
   echo -e "    - ZFS Compression MUST BE DISABLED"
   echo -e "    - ZFS Automatic Snapshots MUST BE DISABLED"
   echo -e "    - ZFS Autotrim SHOULD BE ENABLED"
   echo -e "Otherwise this will eventually fill up the Disk to 100% Usage, even though not much Space at all is being actually used"
   echo -e "\nThis can be done EITHER on the HOST LEVEL (e.g. Proxmox VE) **OR** in the Podman Virtual Machine (if you are setting up one now)"
   echo -e "\nIn case you wish to perform such Operations on the HOST LEVEL (e.g. Proxmox VE), then you'll have to manually issue the following Commands:"
   echo -e "    - zfs set com.sun:auto-snapshot=false rpool/data/<my-vm-disk>"
   echo -e "    - zfs set compression=off rpool/data/<my-vm-disk>"
   echo -e "IMPORTANT: ZFS Autotrim should **ANYWAY** be ENABLED in the **GUEST** ZFS Pool (or you must manually run the zpool trim <mypool> Command)"

   read -p "Do you want to FORCEFULLY DISABLE ZFS Compression (zfs set compression=off <all-datasets>) [y/n]: " forcezfsnocompression
   read -p "Do you want to FORCEFULLY DISABLE ZFS Automatic Snapshots (zfs set com.sun:auto-snapshot=false <all-datasets>) [y/n]: " forcezfsnoautomaticsnapshots
   read -p "Do you want to FORCEFULLY ENABLE ZFS Autotrim (zpool set autotrim=on <mypool>) [y/n]: " forcezfsautotrim

elif [[ "${mode}" == "zvol" ]]
then
   storage=${3:-'zdata/PODMAN'}
   destination=${4:-"/home/${user}/containers"}
else
   echo "Storage mode <${mode}> NOT supported. Aborting !"
   exit 2
fi

# ZVOL FS (if type=zfs)
#fs=${4:-'ext4'}

# Setup container user
touch /etc/{subgid,subuid}
useradd -c "${user}" -s /bin/bash "${user}"
passwd -d "${user}"
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "${user}"
passwd "${user}"

nano /etc/subuid
nano /etc/subgid

# Enable ZFS Pool Autotrim
if [[ "${forcezfsautotrim}" == "y" ]]
then
   # Get Pool Name
   IFS='/'
   read -ra storageparts <<< "${storage}"
   poolname="${storageparts[0]}"

   # Enable ZFS Pool Autotrim
   zpool set autotrim=on ${poolname}
fi

# Default ZFS Compression
zfsdefaultcompression="lz4"
if [[ "${forcezfsnocompression}" == "y" ]]
then
    zfsdefaultcompression="off"
fi

if [ "${mode}" == "zvol"  ]
then
    # Create Root storage
    zfs create -o compression=${zfsdefaultcompression} -o canmount=on ${storage}

    # Allow over-subscribind in case of ZVOL
    zfs set refreservation=none ${storage}
elif [ "${mode}" == "zfs"  ]
then
    # Create Root storage
    zfs create -o compression=${zfsdefaultcompression} -o canmount=on ${storage}

    # Enable mounting of ZFS datasets
    zfs set canmount=on ${storage}
fi

# Disable ZFS Automatic Snapshots
if [[ "${forcezfsnoautomaticsnapshots}" == "y" ]]
then
    zfs set com.sun:auto-snapshot=false ${storage}
fi

# Setup FSTAB
echo "# ${user} BIND Mounts" >> /etc/fstab

if [ "${mode}" == "zfs" ] || [ "${mode}" == "zvol" ]
then
    echo "/${storage}/CONFIG			/home/${user}/.config/containers	none	defaults,nofail,x-systemd.automount,rbind	0	0" >> /etc/fstab
else
    echo "/home/${user}/containers/config	/home/${user}/.config/containers	none	defaults,nofail,x-systemd.automount,rbind	0	0" >> /etc/fstab
fi


mkdir -p "/home/${user}"
chattr -i "/home/${user}"
mkdir -p "/home/${user}/.config"
mkdir -p "/home/${user}/.config/containers"
mkdir -p "/home/${user}/.config/systemd"

# Ensure proper permissions for config folder
chown -R ${user}:${user} /home/${user}/.config/containers

# Chattr .config/containers directory
chattr +i /home/${user}/.config/containers

# Initialize Counter
counter=0

# Create Datasets
for dataset in "${datasets[@]}"
do
	# Convert dataset name to lowercase mountpoint
	lname=${dataset,,}

        # Get name
        name="${storage}/${dataset}"

        # Get compression value
        compression="${compressions[${counter}]}"

        # Get recordsize value
        recordsize="${recordsizes[${counter}]}"

        # The volblocksize value is the same as recordsize (only keep one Array for Configuration)
        volblocksize="${recordsize}"

	# Create storage for image directory
	mkdir -p ${destination}/${lname}/
	umount_if_mounted ${destination}/${lname}/
	chattr -i ${destination}/${lname}/
	chown -R ${user}:${user} ${destination}/${lname}/

        # Disable ZFS Automatic Snapshots
        if [[ "${forcezfsnoautomaticsnapshots}" == "y" ]]
        then
            zfs set com.sun:auto-snapshot=false ${name}
        fi

        # Default ZFS Compression
        zfsdefaultcompression="lz4"
        if [ "${forcezfsnocompression}" == "y" ] && [ "${compression}" != "${zfsdefault}" ]
        then
            # Force Compression Property
            set_zfs_property "${name}" "compression" "off"
        fi

	if [ "${mode}" == "zfs"  ]
	then
	     # Ensure that Mountpoint cannot contain Files UNLESS Dataset is mounted (user Folder)
             chattr +i ${destination}/${lname}/

	     # Ensure that Mountpoint cannot contain Files UNLESS Dataset is mounted (pool Folder)
             chattr +i "/${name}"

	     # Create Dataset
             zfs create ${name}

             # Set Compression Property
             set_zfs_property "${name}" "compression" "${compression}"

             # Set Recordsize Property
             set_zfs_property "${name}" "recordsize" "${recordsize}"

	     # Add FSTAB entry
	     echo "/${name}			${destination}/${lname}		none	defaults,nofail,x-systemd.automount,rbind	0	0" >> /etc/fstab

             # Mount dataset
             zfs mount ${name}

	     # Wait a bit
	     sleep 1
        elif [ "${mode}" == "zvol" ]
	then
	     # Ensure that mountpoint cannot contain files UNLESS dataset is mounted (user folder)
             chattr +i ${destination}/${lname}/

	     # Get ZVOL size
             zsize="${sizes[${counter}]}"

	     # Create ZVOL
	     zfs create -s -V ${zsize} ${name}

             # Set Compression Property
             set_zfs_property "${name}" "compression" "${compression}"

             # Set VolBlocksize Property
             set_zfs_property "${name}" "volblocksize" "${volblocksize}"

	     # Create EXT4 Filesystem
             mkfs.ext4 /dev/zvol/${name}

	     # Wait a bit
	     sleep 1

	     # Add FSTAB entry
             echo "/dev/zvol/${name} ${destination}/${lname} ext4 defaults,nofail,x-systemd.automount 0 0" >> /etc/fstab
        elif [ "${mode}" == "dir" ]
	then
	     # Ensure that mountpoint can contain files since nothing will be mounted there in this mode (user folder)
             chattr -i ${destination}/${lname}/

	else
	     echo "MODE is invalid. It should either be <zfs> or <zvol>. Current value is <${mode}>"
	     echo "Aborting ..."
	     exit;
	fi

	# Reload systemd to make use of new FSTAB
	systemctl daemon-reload

	# Mount according to FSTAB
        if [ "${mode}" == "zfs" ] || [ "${mode}" == "zvol" ]
        then
	    mount ${destination}/${lname}/
        fi

	# Ensure proper permissions
	chown -R ${user}:${user} ${destination}/${lname}/

        # Increment counter
        counter=$((counter+1))
done

# Create symbolic links for "legacy" versions of podmans (e.g. not supporting "volumepath" or "imagestore" configuration directives)
rm -f ${destination}/storage/volumes
ln -s ${destination}/volumes ${destination}/storage/volumes
chown ${user}:${user} ${destination}/storage/volumes

# Save Current Path
scriptspath=$(pwd)

# Install requirements
if [ "${distribution}" == "debian" ] || [ "${distribution}" == "ubuntu" ]
then
   # Enable Backports Repository
   # Copy Debian Backports Repository Configuration
   cp repositories/debian/bookworm/sources.list.d/debian-backports.list /etc/apt/sources.list.d/debian-backports.list

   # Install Packages
   apt-get install --yes sudo aptitude jq podman python3 python3-pip podman-compose

   # Install podman-compose (only relevant if NOT using Debian Backports)
   #pip3 install podman-compose # Use latest version
   #pip3 install https://github.com/containers/podman-compose/archive/refs/tags/v0.1.10.tar.gz # Use legacy version
elif [ "${distribution}" == "ubuntu" ]
then
   # Install Packages
   apt-get install --yes sudo aptitude jq podman python3 python3-pip podman-compose
elif [ "${distribution}" == "fedora" ]
then
   # Install Packages
   dnf install -y sudo jq podman python3 python3-pip podman-compose
else
    echo "[ERROR]: Distribution ${distribution} is NOT Supported. ABORTING !"
    exit 9
fi

# Create /etc/sysctl.d Folder if not exist yet
mkdir -p /etc/sysctl.d

# Allow unprivileged ports <1024 for rootless install
echo "net.ipv4.ip_unprivileged_port_start=80" >> /etc/sysctl.d/99-podman.conf

# Allong rootless Containers to ping
echo "net.ipv4.ping_group_range=0 2000000" >> /etc/sysctl.d/99-podman.conf

# Allow unprivileged network access
echo "kernel.unprivileged_userns_clone=1" >> /etc/sysctl.d/99-podman.conf

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
if [ "${mode}" == "zfs" ] || [ "${mode}" == "zvol" ]
then
   zfs mount -a
   sleep 2
fi

# Automatically bind-mount remaining datasets
mount -a

# Create folder for running processes
userid=$(id -u ${user})
mkdir -p /var/run/user/${userid}
chown -R ${user}:${user} /var/run/user/${userid}
#su ${user}

# Populate config directory
mount /home/${user}/.config/containers
cd /home/${user}/.config/containers || exit
#wget https://src.fedoraproject.org/rpms/containers-common/raw/main/f/storage.conf -O storage.conf
#wget https://src.fedoraproject.org/rpms/containers-common/raw/main/f/registries.conf -O registries.conf
#wget https://src.fedoraproject.org/rpms/containers-common/raw/main/f/default-policy.json -O default-policy.json
#wget https://src.fedoraproject.org/rpms/containers-common/raw/main/f/containers.conf -O containers.conf

cp ${toolpath}/config/containers/storage.conf storage.conf
cp ${toolpath}/config/containers/registries.conf registries.conf
cp ${toolpath}/config/containers/default-policy.json default-policy.json
cp ${toolpath}/config/containers/containers.conf containers.conf

# Create registries.conf.d directory for registries
mkdir -p registries.conf.d

# Setup folders and set correct permissions
chown -R ${user}:${user} /home/${user}

# Set
tee ${homedir}/.bash_profile << EOF
# Include Generic Profile
source /etc/skel/.bashrc

# Include .bashrc
if [ -f ~/.bashrc ]; then
   . ~/.bashrc
fi

# Podman Configuration
export XDG_RUNTIME_DIR=/run/user/${userid}
export XDG_CONFIG_HOME="/home/podman/.config"
#export CONTAINERS_CONF_OVERRIDE="${XDG_CONFIG_HOME}/containers/containers.conf"
#export CONTAINERS_STORAGE_CONF_OVERRIDE="${XDG_CONFIG_HOME}/containers/storage.conf"
#export CONTAINERS_REGISTRIES_CONF_OVERRIDE="${XDG_CONFIG_HOME}/containers/registries.conf"

# Load Helper Functions
if [ -f ~/tools/helpers.sh ]
then
   source ~/tools/helpers.sh
fi
EOF

# Not needed anymore since now .bash_profile will also load .bashrc (if that file exists)
#echo "export XDG_RUNTIME_DIR=/run/user/${userid}" >> /home/${user}/.bashrc


# Change some configuration in storage.conf
sed -Ei "s|^#? ?runroot = \".*\"|runroot = \"/run/user/${userid}\"|g" storage.conf
sed -Ei "s|^#? ?graphroot = \".*\"|graphroot = \"${destination}/storage\"|g" storage.conf
sed -Ei "s|^#? ?rootless_storage_path = \".*\"|rootless_storage_path = \"${destination}/storage\"|g" storage.conf
sed -Ei "s|^#? ?imagestore = \".*\"|#imagestore = \"${destination}/images\"|g" storage.conf
sed -Ei "s|^#? ?mount_program = \".*\"|mount_program = \"/usr/bin/fuse-overlayfs\"|g" storage.conf

# Disable "/usr/lib/containers/storage" as additionalimagestores for Debian
sed -Ei "s|^\"/usr/lib/containers/storage\",\s*?|#\"/usr/lib/containers/storage\",|g" storage.conf

# Change some configuration in containers.conf
sed -Ei "s|^#? ?volume_path = \".*\"|volume_path = \"${destination}/volumes\"|g" containers.conf
sed -Ei "s|^#? ?volumepath = \".*\"|volumepath = \"${destination}/volumes\"|g" containers.conf

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
if [ "${distribution}" == "debian" ] || [ "${distribution}" == "ubuntu" ]
then
   # Perform Upgrade
   apt-get --yes dist-upgrade
elif [ "${distribution}" == "fedora" ]
then
   # Perform Upgrade
   dnf upgrade --refresh
fi

# Rebuild initramfs
update-initramfs -k all  -u

# Setup Systemd
# Source: https://salsa.debian.org/debian/libpod/-/blob/debian/sid/contrib/systemd/README.md#user-podman-service-run-as-given-user-aka-rootless
# Need to execute as podman user
# Setup files
sudo -u ${user} mkdir -p /home/${user}/.config/systemd/user
sudo -u ${user} cp /lib/systemd/user/podman.service /home/${user}/.config/systemd/user/
sudo -u ${user} cp /lib/systemd/user/podman.socket /home/${user}/.config/systemd/user/
sudo -u ${user} cp /lib/systemd/user/podman-auto-update.timer /home/${user}/.config/systemd/user/
sudo -u ${user} cp /lib/systemd/user/podman-auto-update.service /home/${user}/.config/systemd/user/
sudo -u ${user} cp /lib/systemd/user/podman-restart.service /home/${user}/.config/systemd/user/

# Install additionnal packages
if [ "${distribution}" == "debian" ] || [ "${distribution}" == "ubuntu" ]
then
   apt-get --yes install uidmap fuse-overlayfs slirp4netns containernetworking-plugins
elif [ "${distribution}" == "fedora" ]
then
   # shadow-utils is the Fedora Packages corresponding to uidmap in Debian (providing getsubids, newgidmap, newuidmap)
   dnf install -y shadow-utils fuse-overlayfs slirp4netns containernetworking-plugins
fi

# Disable root-level services
# (this Script defaults to rootless podman Installation)
systemctl disable podman-restart.service
systemctl disable podman.socket
systemctl disable podman-auto-update

# Enable user-level services
systemd_enable "${user}" "podman.socket"
systemd_restart "${user}" "podman.socket"

systemd_enable "${user}" "podman.service"
systemd_restart "${user}" "podman.service"

systemd_enable "${user}" "podman-restart.service"
systemd_restart "${user}" "podman-restart.service"

systemd_enable "${user}" "podman-auto-update.service"
systemd_restart "${user}" "podman-auto-update.service"

systemd_status "${user}" "podman.socket podman.service podman-restart.service podman-auto-update.service"
systemd_reexec "${user}"
systemd_reload "${user}"

# https://github.com/containers/podman/issues/3024#issuecomment-1742105831 ,  https://github.com/containers/podman/issues/3024#issuecomment-1762708730
mkdir -p /etc/systemd/system/user@.service.d
cd /etc/systemd/system/user@.service.d || exit
echo "[Service]" > override.conf
echo "OOMScoreAdjust=" >> override.conf

# Prevent Systemd from auto restarting Podman Containers too quickly and timing out
cd ${scriptspath} || exit
mkdir -p /etc/systemd/user.conf.d/
cp systemd/conf/podman.systemd.conf /etc/systemd/user.conf.d/podman.conf

# Increase Limits on Maximum Number of Open Files
sudo sh -c "echo '* soft     nofile         65535
* hard     nofile         65535' > /etc/security/limits.d/30-max-number-open-files.conf"

# Enable rc.local service and make sure ZFS dataset are mounted BEFORE everything else
source enable_rc_local.sh

#################################################
################### User Level ##################
#################################################
# Setup a copy of the tool for user
cd ${homedir} || exit
if [[ ! -d "tools" ]]
then
   git clone https://github.com/luckylinux/podman-tools.git tools
else
   git pull
fi

# Ensure propert Permissions
chown -R ${user}:${user} "tools/"

# Move to the local copy of the tool for the user
cd tools || exit

# Setup CRON/Systemd to automatically install images updates
source setup_podman_autoupdate_service.sh

# Setup CRON/Systemd to automatically generate updated Systemd Service files
source setup_podman_autostart_service.sh

# Setup CRON/Systemd to automatically detect traefik changes and restart traefik to apply them
source setup_podman_traefik_monitor_service.sh

# Setup CRON/Systemd job to automatically update the Podman Tools (run git pull from toolpath)
source setup_tools_autoupdate_service.sh
