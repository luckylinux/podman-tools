#!/bin/bash

# Save current pwd
currentpath=$(pwd)

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load functions
source ${toolpath}/functions.sh

# Define user
if [[ -z "${user}" ]]
then
   # If it's not passed as argument then use the current User
   user=$(whoami)
fi

# Define mode
if [[ -z "${schedulemode}" ]]
then
   if [[ "${user}" == "root" ]]
   then
        schedulemode=${2:-""}

        if [[ -z "${schedulemode}" ]]
        then
            # Default to Systemd
            schedulemode="systemd"
        fi
   else
        schedulemode="systemd"
   fi
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
# homedir=$(get_homedir "${user}")

# Determine toolsdir
toolsdir=$(get_toolsdir "${user}")

if [[ "${schedulemode}" == "cron" ]]
then
   # Setup CRON to automatically generate updated Systemd Service files
   destination="/etc/cron.d/podman-tools-autoupdate"
   cp "cron/podman-tools-autoupdate" "${destination}"
   chmod +x "${destination}"
   replace_text "${destination}" "toolpath" "${toolsdir}" "user" "${user}"
elif [[ "${schedulemode}" == "systemd" ]]
then
   # Get Systemdconfigdir
   systemdconfigdir=$(get_systemdconfigdir "${user}")

   # Copy Systemd Service File
   filename="podman-tools-autoupdate.service"
   destination="${systemdconfigdir}/${filename}"
   cp "systemd/services/${filename}" "${destination}"
   # chmod +x "${destination}"
   replace_text "${destination}" "toolpath" "${toolsdir}" "user" "${user}"
   systemd_reload_enable "${user}" "${filename}"

   # Copy Systemd Timer File
   filename="podman-tools-autoupdate.timer"
   destination="${systemdconfigdir}/${filename}"
   cp "systemd/timers/${filename}" "${destination}"
   # chmod +x "${destination}"
   replace_text "${destination}" "toolpath" "${toolsdir}" "user" "${user}"
   systemd_reload_enable "${user}" "${filename}"
else
   # Error
   schedule_mode_not_supported "${schedulemode}"
fi
