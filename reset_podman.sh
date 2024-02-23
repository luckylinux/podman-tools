#!/bin/bash

# Define user
# User name - Default: podman
user=${1:-'podman'}

# Save current path
currentpath=$(pwd)

# Base path
basepath="/home/$user"

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
    cd "$basepath/compose/$container"
#    runuser -l podman -c "podman-compose down -d"
    podman-compose down
done

# Switch back to current path
cd $currentpath

# Force remove storage
# List storage
mapfile -t storages < <( podman ps --all --storage --format="{{.Names}}" )
for storage in "${storages[@]}"
do
    podman rm --storage $storage
done

# Perform a system reset
#runuser -l podman -c "podman system reset"
podman system reset
