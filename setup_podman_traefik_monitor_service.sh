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
#   schedulemode=${2:-"cron"}
   schedulemode="systemd"
fi

# Get user home folder
userhomedir=$( get_homedir "${user}" )

# Systemd based Distribution
if [[ $(command -v systemctl) ]]
then
    # Get Systemd Config Folder
    systemdconfigfolder=$( get_systemdconfigdir "${user}" )
else
    # Systemd is not available
    # Force Cron
    schedulemode="cron"
fi

# Generate Path to Install Executable
localbinpath=$( get_localbinpath "${user}" )

# Make sure that the Traefik Systemd Service has already been set up
${toolpath}/configure_podman_service_autostart.sh "traefik"

# Define Service Name
servicename="monitor-traefik"

# Define Service File
servicefile="${servicename}.service"

# Echo
echo "Setup Traefik Monitoring Service for User <${user}>"

# Copy Traefik Monitoring Script to Podman User Folder
mkdir -p "${localbinpath}"
cp "${toolpath}/bin/monitor-traefik.sh" "${localbinpath}/monitor-traefik.sh"
chown "${user}:${user}" "${localbinpath}/monitor-traefik.sh"

# Give Script Execution Permissions
chmod +x "${localbinpath}/monitor-traefik.sh"

# Systemd based Distribution
if [[ $(command -v systemctl) ]]
then
    # Echo
    echo "Installing Systemd Service file to <${systemdconfigfolder}/${servicefile}>"

    # Copy Traefik Monitoring Service File to Podman Systemd Service Folder
    cp "${toolpath}/systemd/services/${servicefile}" "${systemdconfigfolder}/${servicefile}"
    chown "${user}:${user}" "${systemdconfigfolder}/${servicefile}"

    # Make sure that the correct Path is set in the Service for localbinpath
    replace_text "${systemdconfigfolder}/${servicefile}" "localbinpath" "${localbinpath}"

    # Enable & Start Systemd file
    systemd_reload_enable "${user}" "${servicefile}"
fi
