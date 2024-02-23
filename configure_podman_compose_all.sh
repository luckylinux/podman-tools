#!/bin/bash

# Define user
# User name - Default: podman
user=${1:-'podman'}

# Save current path
currentpath=$(pwd)

# Bring up all containers using podman-compose
for filename in /home/$user/compose/*
do
    container=$(basename $filename)
    cd "$currentpath/compose/$container"
#    runuser -l podman -c "podman-compose up -d"
    podman-compose up -d
done

# Change back to current path
cd $currentpath

# Setup autostart for all containers
bash "./configure_podman_service_autostart_all.sh"
