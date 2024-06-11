#!/bin/bash

###################################################
## IMPORTANT: THIS FILE MUST BE RUN **MANUALLY** ##
###################################################

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load functions
source ${toolpath}/functions.sh

# Define user
if [[ ! -v user ]]
then
#   user=${1:-'podman'}
   user=$(whoami)
fi

# Define mode
if [[ ! -v schedulemode ]]
then
#   schedulemode=${2:-'cron'}
   schedulemode='systemd'
fi

# Get homedir
homedir=$(get_homedir "${user}")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "${user}")

# Setup venv
generic_cmd "${user}" "cd ~ ; python3 -m venv ~/podman-compose ; source ~/podman-compose/bin/activate ; pip install git+https://github.com/containers/podman-compose.git@v1.1.0"
