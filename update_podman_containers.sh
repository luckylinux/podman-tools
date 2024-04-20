#!/bin/bash

# Save current pwd
currentpath=$(pwd)

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load functions
source ${toolpath}/functions.sh

# Define user
user=${1}
if [[ -v user ]]
then
   user=$(whoami)
fi

# Get user homedir
userhomedir=$(get_homedir "${user}")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "${user}")

# Prune old images
podman image prune -f

# List all images
mapfile -t images < <( podman images --all --format="{{.Names}}" )

# Iterate over images
for image in "${images[@]}"
do
    # Remove Square brackets []
    source=$(echo ${image} | sed 's/[][]//g')

    # If source is non-null then try to pull image
    if [[ -v source ]]
    then
        # Pull (new ?) image
        podman pull ${source}
    fi
done

# Restart Systemd Container Services
cd ${systemdconfigdir} || exit
for service in container-*.service
do
    # Get Service Name (without Path or "./")
    servicename=$(basename "${service}")

    # Restart container
    systemd_restart "${user}" "${servicename}"
done

# Change back to currentpath
cd ${currentpath} || exit

# Restart the podman-auto-update.service Systemd Service
# This forces old images to be purges and news ones to be fetched
systemctl --user restart podman-auto-update.service
