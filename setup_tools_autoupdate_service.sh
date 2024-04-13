#!/bin/bash

# Save current pwd
currentpath=$(pwd)

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load functions
source $toolpath/functions.sh

# Define user
user=$1
if [[ -v user ]]
then
   user=$(whoami)
fi

# Define mode
if [[ ! -v schedulemode ]]
then
   if [[ "$user" == "root" ]]
   then
        schedulemode=${2:-'cron'}
   else
        schedulemode='systemd'
   fi
fi

# Get homedir
homedir=$(get_homedir "$user")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "$user")

if [[ "$schedulemode" == "cron" ]]
then
   # Setup CRON to automatically generate updated Systemd Service files
   destination="/etc/cron.d/podman-tools-autoupdate"
   cp "cron/podman-tools-autoupdate" "$destination"
   chmod +x "$destination"
   replace_text "$destination" "toolpath" "$toolpath" "user" "$user"
elif [[ "$schedulemode" == "systemd" ]]
then
   # Copy Systemd Service File
   filename="podman-tools-autoupdate.service"
   destination="$systemdconfigdir/$filename"
   cp "systemd/services/$filename" "$destination"
   chmod +x "$destination"
   replace_text "$destination" "toolpath" "$toolpath" "user" "$user"
   systemd_reload_enable "$user" "$filename"

   # Copy Systemd Timer File
   filename="podman-tools-autoupdate.timer"
   destination="$systemdconfigdir/$filename"
   cp "systemd/timers/$filename" "$destination"
   chmod +x "$destination"
   replace_text "$destination" "toolpath" "$toolpath" "user" "$user"
   systemd_reload_enable "$user" "$filename"
else
   # Error
   schedule_mode_not_supported "$schedulemode"
fi
