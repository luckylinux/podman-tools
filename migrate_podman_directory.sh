#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load Configuration
source $toolpath/config.sh

# Load Functions
source $toolpath/functions.sh

# User Name
user=$1
#user=${1-"podman"}

# Source Directory
sourcedir=$2
#sourcedir=${2-"/home/podman"}

# Destination Directory
destinationdir=$3
#destinationdir=${3-"/home/podman/containers"}

# Create Destination Directory if Not Existing Yet
mkdir -p ${destinationdir}
chown -R $user:$user ${destinationdir}

# Storage.conf File Location
# MUST still be available after all things have been unmounted
configrealpath=$4
#configrealpath=${4-"/zdata/PODMAN/CONFIG"} # Contains storage.conf

# Relative Path compared to Homedir
relativepath=$(realpath --canonicalize-missing ${sourcedir/$homedir/""})

# Save current path
currentpath=$(pwd)

# Get homedir
homedir=$(get_homedir "$user")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "$user")

# Stop all Running Containers based only on Podman Running Status
mapfile -t list < <( podman ps --all --format="{{.Names}}" )

for container in "${list[@]}"
do
   echo "Disable & Stop Systemd Autostart Service for <${container}>"

   # Define where service file would be located
   servicename="container-${container}"

   # Disable Service Temporarily
   systemd_disable "$user" "$service"

   # Stop Service
   systemd_stop "$user" "$service"
done

# Stop all Containers based on Podman Compose file Structure
for filepath in $sourcedir/compose/*
do
   # Container is only the basename
   container=$(basename $filepath)

   echo "Run podman-compose down for <${container}>"

   # Change Directory
   cd $sourcedir/compose/$container

   # Brind Podman Container down
   podman-compose down
done

# Make changes to storage.conf
sed -Ei "s|^#? ?graphroot = \".*\"|graphroot = \"${destinationdir}/storage\"|g" ${configrealpath}/storage.conf
sed -Ei "s|^#? ?rootless_storage_path = \".*\"|rootless_storage_path = \"${destinationdir}/storage\"|g" ${configrealpath}/storage.conf

# Using Imagestore gives problems so make sure to Disable it in the Process !
sed -Ei "s|^#? ?imagestore = \".*\"|#imagestore = \"${destinationdir}/images\"|g" ${configrealpath}/storage.conf

# Make changes to registries.conf
# ...

# Make changes to containers.conf
# Also fix wrong "volumepath" syntax to the correct "volume_path"
sed -Ei "s|^#? ?volumepath = \".*\"|volume_path = \"${destinationdir}/volumes\"|g" ${configrealpath}/storage.conf
sed -Ei "s|^#? ?volume_path = \".*\"|volume_path = \"${destinationdir}/volumes\"|g" ${configrealpath}/storage.conf

# Unmount all mountpoints
zfs umount -a
umount -a

# Loop over Datasets
# Create Datasets
for dataset in "${datasets[@]}"
do
        # Convert dataset name to lowercase mountpoint
        lname=${dataset,,}

        # Source Path
        sourcepath="${sourcedir}/${lname}"

        # Destination Path
        destionationpath="${destinationdir}/${lname}"

        # If dataset does not exist yet, create it
        if [[ ! -d "${sourcepath}" ]]
        then
           mkdir -p "${sourcepath}"
           chown -R $user:$user $sourcedir/${lname}
        fi

        # Make it editable
        chattr -i ${sourcepath}

        # Move mountpoint
        mv ${sourcepath} ${destinationpath}

        # Give User Ownership
        chown -R $user:$user ${destinationpath}

        # Require that a partition is mounted there again
        chattr +i ${destinationpath}

        # Make changes to /etc/fstab
        sed -Ei "s|${sourcepath}|${destinationpath}|g" /etc/fstab.conf
done

# Remount all mountpoints
zfs mount -a
mount -a

# Reset podman as user
generic_cmd "$user" "podman" "system" "reset"

# Remove remaining stuff in storage and images
rm -rf ${sourcedir}/storage/*
rm -rf ${sourcedir}/images/*

# Shoud Reboot
echo "You should now Reboot !"
