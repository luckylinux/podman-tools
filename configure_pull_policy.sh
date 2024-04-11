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

# Base Directory
basedir=$2
#basedir=${2-"/home/podman"}

# Set Value ("always" / "missing")
pullpolicy=$3
#pullpolicy=${3-"missing"}

# Check if pull_policy is valid
if [[ "${pullpolicy}" != "always" ]] && [[ "${pullpolicy}" != "missing" ]]
then
   echo "ERROR: pull_policy must be one of: <always>, <missing>. Entered value was <${pullpolicy}>. Aborting."
   exit 9
fi

# Save current path
currentpath=$(pwd)

# Get homedir
homedir=$(get_homedir "$user")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "$user")

# Modify all Containers based on Podman Compose file Structure
for containerpath in $basedir/compose/*
do
   # Get only container name
   container=$(basename $containerpath)

   echo "Reconfigure Pull policy to <${pullpolicy}> for <${container}>"

   # Change Directory
   cd $basedir/compose/$container

   if [[ -f "compose.yml" ]]
   then
       # Replace pull_policy string
       echo "Replace pull_policy in <$basedir/compose/$container/compose.yml>"

       #sed -Ei "s|^#(\s*)pull_policy\s*?:\s*?\".*\"(.*)$|\1pull_policy: \"${pullpolicy}\"\2|g" compose.yml         # This pull_policy is anyways DISABLED so no need to replace it
       sed -Ei "s|^(\s*)pull_policy\s*?=\s*?\".*\"(.*)$|\1pull_policy: \"${pullpolicy}\"\2|g" compose.yml           # Fix error in previos versions (= -> :) 
       sed -Ei "s|^(\s*)pull_policy\s*?:\s*?\".*\"(.*)$|\1pull_policy: \"${pullpolicy}\"\2|g" compose.yml           # This pull_policy is ENABLED so it MUST be replaced
   else
       # File does not exist
       echo "File <$basedir/compose/$container/compose.yml>. No replacement performed."
   fi

   # Brind Podman Container down
   #podman-compose down
done


# Stop all Running Containers based only on Podman Running Status
mapfile -t list < <( podman ps --all --format="{{.Names}}" )

for container in "${list[@]}"
do
   # Get compose file location from Container Properties
   composedir=$(podman inspect $container | jq -r '.[0].Config.Labels."com.docker.compose.project.working_dir"')

   # Get systemd service name
   service=$(podman inspect $container | jq -r '.[0].Config.Labels."PODMAN_SYSTEMD_UNIT"')

   echo -e "Run podman-compose down & podman-compose up -d <${container}> which is currently running"
   echo -e "\t Compose Directory: ${composedir}"
   echo -e "\t Systemd Service: ${service}"

   # Disable Service Temporarily
   systemd_disable "$user" "$service"

   # Stop Service
   systemd_stop "$user" "$service"

   # Change Directory
   cd $composedir

   # Bring Container Down
   podman-compose down

   # Wait a bit
   sleep 0.5

   # Bring Container Up
   podman-compose up -d

   # Re-enable Service
   systemd_enable "$user" "$service"

   # Restart Service
   systemd_restart "$user" "$service"
done

# Re-enable all containers
#source $toolpath/configure_podman_service_autostart_all.sh
