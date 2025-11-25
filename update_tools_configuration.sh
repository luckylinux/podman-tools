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

# Setup CRON/Systemd to automatically install images updates
source setup_podman_autoupdate_service.sh

# Setup CRON/Systemd to automatically generate updated Systemd Service files
source setup_podman_autostart_service.sh

# Setup CRON/Systemd to automatically detect traefik changes and restart traefik to apply them
# source setup_podman_traefik_monitor_service.sh

# Setup CRON/Systemd job to automatically update the Podman Tools (run git pull from toolpath)
# Deprecated now that Quadlets are used
# source setup_tools_autoupdate_service.sh

