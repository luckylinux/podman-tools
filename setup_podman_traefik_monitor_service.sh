#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load functions
source "${toolpath}/functions.sh"

# Define user
#user=${1}
if [[ -z "${user}" ]]
then
   user=$(whoami)
fi

# Define mode
if [[ -z "${schedulemode}" ]]
then
#   schedulemode=${2:-'cron'}
   schedulemode='systemd'
fi

# Get user home folder
userhomedir=$( get_homedir "${user}" )

# Get Systemd Config Folder
systemdconfigfolder=$( get_systemdconfigdir "${user}" )

# Generate Path to Install Executable
localbinpath=$( get_localbinpath "${user}" )

# Make sure that the Traefik Systemd Service has already been set up
${toolpath}/configure_podman_service_autostart.sh "traefik"

# Define service name
service="monitor-traefik.service"

# Echo
echo "Setup Traefik Monitoring Service for User <${user}>"

# Copy Traefik Monitoring Script to Podman User Folder
mkdir -p "${localbinpath}"
cp "${toolpath}/bin/monitor-traefik.sh" "${localbinpath}/monitor-traefik.sh"
chown "${user}:${user}" "${localbinpath}/monitor-traefik.sh"

# Give Script Execution Permissions
chmod +x "${localbinpath}/monitor-traefik.sh"

# Echo
echo "Installing Systemd Service file in <${systemdconfigfolder}/${service}>"

# Copy Traefik Monitoring Service File to Podman Systemd Service Folder
cp "${toolpath}/systemd/services/${service}" "${systemdconfigfolder}/${service}"
chown "${user}:${user}" "${systemdconfigfolder}/${service}"

# Make sure that the correct Path is set in the Service for localbinpath
replace_text "${systemdconfigfolder}/${service}" "localbinpath" "${localbinpath}"

# Enable & Start Systemd file
systemd_reload_enable "${user}" "${service}"
