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

# Paths for use in config files
# It's better to avoid using --rbind paths such as /home/podman/containers/storage for graphRoot and similar.
# Less issues when accessing directly /zdata/PODMAN/*
# The mountpoints is still available though
# If SET, the UPPERCASE Dataset values will be used (STORAGE, IMAGES, VOLUMES, ...)
# If UNSET, the LOWERCASE Dataset values will be used (storage, images, volumes, ...)
pathsforuseinconfigfiles=${5-""}

# Relative Path compared to Homedir
relativepath=$(realpath --canonicalize-missing ${sourcedir/$homedir/""})

# Save current path
currentpath=$(pwd)

# Get homedir
homedir=$(get_homedir "${user}")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "${user}")

# Stop all Running Containers based only on Podman Running Status
mapfile -t list < <( podman ps --all --format="{{.Names}}" )

for container in "${list[@]}"
do
   echo "Disable & Stop Systemd Autostart Service for <${container}>"

   # Define where service file would be located
   servicename="container-${container}"

   # Disable Service Temporarily
   systemd_disable "${user}" "${service}"

   # Stop Service
   systemd_stop "${user}" "${service}"
done

# Stop all Containers based on Podman Compose file Structure
for filepath in ${sourcedir}/compose/*
do
   # Container is only the basename
   container=$(basename ${filepath})

   echo "Run podman-compose down for <${container}>"

   # Change Directory
   cd ${sourcedir}/compose/${container}

   # Brind Podman Container down
   podman-compose down
done

# Determine which Paths to use in storage.conf files
if [[ -z "${pathsforuseinconfigfiles}" ]]
then
   storagepath="${destinationdir}/storage"
   imagespath="${destinationdir}/images"
   volumespath="${destinationdir}/volumes"
else
   storagepath="${pathsforuseinconfigfiles}/STORAGE"
   imagespath="${pathsforuseinconfigfiles}/IMAGES"
   volumespath="${pathsforuseinconfigfiles}/VOLUMES"
fi

# Make changes to storage.conf
sed -Ei "s|^#? ?graphroot = \".*\"|graphroot = \"${storagepath}\"|g" ${configrealpath}/storage.conf
sed -Ei "s|^#? ?rootless_storage_path = \".*\"|rootless_storage_path = \"${storagepath}\"|g" ${configrealpath}/storage.conf

# Using Imagestore gives problems so make sure to Disable it in the Process !
sed -Ei "s|^#? ?imagestore = \".*\"|#imagestore = \"${imagespath}\"|g" ${configrealpath}/storage.conf

# Make changes to registries.conf
# ...

# Make changes to containers.conf
# Also fix wrong "volumepath" syntax to the correct "volume_path"
sed -Ei "s|^#? ?volumepath = \".*\"|volume_path = \"${volumespath}\"|g" ${configrealpath}/storage.conf
sed -Ei "s|^#? ?volume_path = \".*\"|volume_path = \"${volumespath}\"|g" ${configrealpath}/storage.conf

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
        destinationpath="${destinationdir}/${lname}"

        # If dataset does not exist yet, create it
        if [[ ! -d "${sourcepath}" ]]
        then
           mkdir -p "${sourcepath}"
           chown -R $user:$user $sourcedir/${lname}
        fi

        # Make it editable
        chattr -i ${sourcepath}

        # If folder has already been created on destination, attempt to remove it (if empty only !)
        if [[ -d "${destinationpath}" ]]
        then
            # Echo
            echo "Destination folder <${destinationpath}> already exists. Attempting to remove (only if EMPTY !)"

            # Make it editable
            chattr -i ${destinationpath}

            # Attempt to Remove it
            rmdir ${destinationpath}

            # Check Return Code
            if [[ "$?" -neq 0 ]]
            then
                echo "FAILED to remove Destination folder <${destinationpath}>. Error code of `rmdir` was $?. Possible NON-EMPTY Directory !"
            fi
        fi

        # Move mountpoint
        mv ${sourcepath} ${destinationpath}

        # Give User Ownership
        chown -R $user:$user ${destinationpath}

        # Require that a partition is mounted there again
        chattr +i ${destinationpath}

        # Make changes to /etc/fstab
        sed -Ei "s|${sourcepath}|${destinationpath}|g" /etc/fstab.conf
done

# Load new FSTAB Configuration
systemctl daemon-reload

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
