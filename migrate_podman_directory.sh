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
sourcedir=$1
#sourcedir=${1-"/home/podman"}

# Destination Directory
destinationdir=$2
#destinationdir=${2-"/home/podman/containers"}

# Storage.conf File Location
# MUST still be available after all things have been unmounted
configrealpath=$3
#configrealpath=${3-"/zdata/PODMAN/CONFIG"} # Contains storage.conf

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
for container in $sourcedir/compose/*
do
   echo "Run podman-compose down for <${container}>"

   # Change Directory
   cd $sourcedir/compose/*

   # Brind Podman Container down
   podman-compose down
done

# Unmount all mountpoints
zfs umount -a
umount -a

# Loop over Datasets
# Create Datasets
for dataset in "${datasets[@]}"
do
        # Convert dataset name to lowercase mountpoint
        lname=${dataset,,}


        # Make it editable
        chattr -i $sourcedir/${lname}

        # Move mountpoint
        mv $sourcedir/${lname} $destinationdir/${lname}

        # Require that a partition is mounted there again
        chattr +i $destinationdir/${lname}

        # Make changes to /etc/fstab
        sed -Ei "s|${sourcedir}/${lname}|${destinationdir}/${lname}|g" /etc/fstab.conf

        # Make changes to storage.conf
        sed -Ei "s|^#? ?graphroot = \".*\"|graphroot = \"${destinationdir}/${lname}\"|g" ${configrealpath}/storage.conf
        sed -Ei "s|^#? ?rootless_storage_path = \".*\"|rootless_storage_path = \"${destinationdir}/${lname}\"|g" ${configrealpath}/storage.conf
        sed -Ei "s|^#? ?imagestore = \".*\"|#imagestore = \"${destinationdir}/{$lname}\"|g" ${configrealpath}/storage.conf

        # Make changes to registries.conf
        # ...

        # Make changes to containers.conf
        sed -Ei "s|^#? ?volume_path = \".*\"|#volume_path = \"${destinationdir}/${lname}\"|g" ${configrealpath}/storage.conf
        #sed -Ei "s|^#? ?volumepath = \".*\"|#volumepath = \"${destinationdir}/${lname}\"|g" ${configrealpath}/storage.conf
done

# Remount all mountpoints
zfs mount -a
mount -a

# Reset podman as user
generic_cmd "$user" "podman" "system" "reset"

# Remove remaining stuff in storage
rm -rf ${sourcedir}/storage/*
