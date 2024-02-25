#!/bin/bash

# Save current pwd
currentpath=$(pwd)

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load functions
source $toolpath/functions.sh

# Define user
user=$1
if [[ -v user ]]
then
   user=$(whoami)
fi

# Get user homedir
userhomedir=$(get_homedir "$user")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "$user")

# Restart Systemd Container Services
cd $systemdconfigdir
for service in "container-*.service"
do
    # Restart container
    systemd_restart "$user" "$service"
done

# Change back to currentpath
cd $currentpath

# Stop Podman "standalone" Containers
mapfile -t list < <( podman ps --all --format="{{.Names}}" )
for container in "${list[@]}"
do
    # Stop Container
    podman stop $container

    # Remove Container
    #podman rm $container
done
