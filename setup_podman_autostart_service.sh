#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load functions
source ${toolpath}/functions.sh

# Deprecated now that Quadlets are used
# Exit immediately to prevent conflicts
exit 0

# Define user
if [[ -z "${user}" ]]
then
#   user=${1:-"podman"}
   user=$(whoami)
fi

# Define mode
if [[ -z "${schedulemode}" ]]
then
#   schedulemode=${2:-"cron"}
   schedulemode="systemd"
fi

# Systemd based Distribution
if [[ $(command -v systemctl) ]]
then
    # Nothing to do
    x=1
else
    # Systemd is not available
    # Force Cron
    schedulemode="cron"
fi

# Get homedir
homedir=$(get_homedir "${user}")

# Systemd based Distribution
if [[ $(command -v systemctl) ]]
then
    # Get Systemdconfigdir
    systemdconfigdir=$(get_systemdconfigdir "${user}")

    # Remove old files / with old name
    #rm -f /etc/...
    systemd_delete "${user}" "podman-setup-service-autostart.service"
    systemd_delete "${user}" "podman-setup-service-autostart.timer"
fi

# Setup new Scheme
if [[ "${schedulemode}" == "cron" ]]
then
   # Setup CRON to automatically generate updated Systemd Service files for Podman

   # Nothing currently implemented for OpenRC
   echo "[WARNING] Currently podman-setup-service-autostart is NOT implemented for OpenRC based Distributions"

   # Disabled for now
   #destination="/etc/cron.d/podman-service-reconfigure-autostart"
   #cp "cron/podman-service-autostart" "${destination}"
   #chmod +x "${destination}"
   #eplace_text "${destination}" "toolpath" "${homedir}/podman-tools" "user" "${user}"
   x=1
elif [[ "${schedulemode}" == "systemd" ]]
then
   # Copy Systemd Service File
   servicefile="podman-service-reconfigure-autostart.service"
   destination="${systemdconfigdir}/${servicefile}"
   cp "systemd/services/${servicefile}" "${destination}"
   chmod +x "${destination}"
   chown "${user}:${user}" "${destination}"
   replace_text "${destination}" "toolpath" "${homedir}/podman-tools" "user" "${user}"
   systemd_reload_enable "${user}" "${servicefile}"

   # Copy Systemd Timer File
   timerfile="podman-service-reconfigure-autostart.timer"
   destination="${systemdconfigdir}/${timerfile}"
   cp "systemd/timers/${timerfile}" "${destination}"
   chmod +x "${destination}"
   chown "${user}:${user}" "${destination}"
   replace_text "${destination}" "toolpath" "${homedir}/podman-tools" "user" "${user}"
   systemd_reload_enable "${user}" "${timerfile}"
else
   # Error
   schedule_mode_not_supported "${schedulemode}"
fi
