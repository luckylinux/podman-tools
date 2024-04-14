#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load Configuration
source $toolpath/config.sh

# Load Functions
source $toolpath/functions.sh

# Attempt to use Argument for Container Name
container=${1-""}

# Setting
setting=${2-"enable"}

# User
user=${3-""}
if [[ -z "$user" ]]
then
   user=$(whoami)
fi

# Validation
if [ "$setting" != "enable" ] && [ "$setting" != "disable" ]
then
   echo "Setting must be one of the following: <enable> or <disable>. Aborting."
   exit 9
fi

# Ask user input if Container Name was not Provided
if [[ -z "$container" ]]
then
   # List Containers
   podman ps --all

   # Ask User Input
   read -p "Container Name to Create Systemd Service for:" container
fi

# Configure Systemd Service
if [ "$setting" == "enable" ]
then
    # Enable Service
    enable_autostart_container "${container}" "${user}"
else
    # Disable Service
    disable_autostart_container "${container}" "${user}"
fi
