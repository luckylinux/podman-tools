#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Base Folder
basefolder=${1-""}

# Ask user input if Container Name was not Provided
if [[ -z "${basefolder}" ]]
then
   # Ask User Input
   read -p "Enter Containers base Folder (e.g. /home/podman/containers) where compose folder is located:" basefolder
fi

# Stop Traefik Monitoring Service
systemctl --user stop monitor-traefik.service

# Stop Traefik Container
systemctl --user stop container-traefik.service

# Run Podman Compose
if [[ -d "$basefolder/compose" ]] && [[ -d "$basefolder/compose/traefik" ]]
then
   # Change Folder
   cd $basefolder/compose/traefik || exit

   # Run podman compose
   podman-compose down
   sleep 1
   podman-compose up -d

   # Update Autostart File to match new Compose File
   bash ${toolpath}/configure_podman_service_autostart.sh "traefik"

   # Restart Traefik Monitoring Service
   systemctl --user restart monitor-traefik.service
else
   echo "Folder ${basefolder}/compose/traefik does NOT exist. Aborting."
   exit 1
fi
