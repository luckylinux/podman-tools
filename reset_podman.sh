#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load Functions
source $toolpath/functions.sh

# Define user
# User name - Default: podman
user=${1:-"podman"}

# Save current path
currentpath=$(pwd)

# Home dir
homedir=$(get_homedir "$user")

# Base path
basepath=${2-"/home/$user/containers"}

# Stop & Disable all Systemd services
for filename in $basepath/.config/systemd/user/default.target.wants/*
do
    service=$(basename $filename)
#    runuser -l podman -c "systemctl --user disable $service"
#    runuser -l podman -c "systemctl --user stop $service"
    systemctl --user disable $service
    systemctl --user stop $service
done

# Perform a podman-compose down first
for filename in $basepath/compose/*
do
    container=$(basename $filename)

    if [[ -d "$basepath/compose/$container" ]]
    then
        cd "$basepath/compose/$container" || exit
        #runuser -l podman -c "podman-compose down -d"
        podman-compose down
    fi
done

# Switch back to current path
cd $currentpath || exit

# Force remove storage
# List storage
mapfile -t storages < <( podman ps --all --storage --format="{{.Names}}" )
for storage in "${storages[@]}"
do
    podman rm --force --storage $storage
done

# Perform a system reset
#runuser -l podman -c "podman system reset"
podman system reset

# Must be run as root/sudo
echo "Removing remaining filees/folder. Needs root privileges !"
#su -c "bash -c \"rm -rf ${homedir}/.local/share/containers/cache/*\""
#su -c "bash -c \"rm -rf ${homedir}/.local/share/containers/storage/*\""
#su -c "bash -c \"rm -rf ${homedir}/.cache/containers/*\""
#su -c "bash -c \"rm -rf ${basepath}/images/*\""
#su -c "bash -c \"rm -rf ${basepath}/storage/*\""
su -c "bash -c \"rm -rf ${homedir}/.local/share/containers/cache/*; rm -rf ${homedir}/.local/share/containers/storage/*; rm -rf ${homedir}/.cache/containers/*; rm -rf ${basepath}/images/*; rm -rf ${basepath}/storage/*\""

# Remove Dangling Network Configuration
rm -f ${XDG_RUNTIME_DIR}/networks/aardvark-dns/*
rm -f ${XDG_RUNTIME_DIR}/networks/aardvark.lock
rm -f ${XDG_RUNTIME_DIR}/networks/ipam.db

