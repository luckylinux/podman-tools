#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load functions
source ${toolpath}/functions.sh

# Define user
if [[ -z "${user}" ]]
then
#   user=${1:-'podman'}
   user=$(whoami)
fi

# Define mode
if [[ -z "${schedulemode}" ]]
then
#   schedulemode=${2:-'cron'}
   schedulemode='systemd'
fi

# Get homedir
homedir=$(get_homedir "${user}")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "${user}")

# Remove old files / with old name
#rm -f /etc/...
systemd_delete "${user}" "podman-delayed-start.service"
systemd_delete "${user}" "podman-delayed-start.timer"

# Setup new Scheme
if [[ "${schedulemode}" == "cron" ]]
then
   # Setup CRON to automatically generate updated Systemd Service files for Podman
   # Disabled for now
   dummyvar=1
elif [[ "${schedulemode}" == "systemd" ]]
then
   # Copy Systemd Service File
   servicefile="podman-delayed-start.service"
   destination="${systemdconfigdir}/${servicefile}"
   cp "systemd/services/${servicefile}" "${destination}"
   chmod +x "${destination}"
   chown "${user}:${user}" "${destination}"
   replace_text "${destination}" "toolpath" "${homedir}/podman-tools" "user" "${user}"
   systemd_reload_enable "${user}" "${servicefile}"
else
   # Error
   schedule_mode_not_supported "${schedulemode}"
fi
