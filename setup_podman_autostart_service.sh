#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load functions
source functions.sh

# Define user
targetuser=${1:-'podman'}

# Define mode
schedulemode=${2:-'cron'}

# Get homedir
homedir=$(get_homedir "$targetuser")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "$targetuser")

if [[ "$schedulemode" == "cron" ]]
then
   # Setup CRON to automatically generate updated Systemd Service files
   destination="/etc/cron.d/podman-service-autostart"
   cp "cron/podman-service-autostart" "$destination"
   chmod +x "$destination"
   replace_text "$destination" "toolpath" "$toolpath" "user" "$targetuser"
elif [[ "$schedulemode" == "systemd" ]]
then
   # Copy Systemd Service File
   filename="podman-setup-service-autostart.service"
   destination="$systemdconfigdir/$filename"
   cp "systemd/services/$filename" "$destination"
   chmod +x "$destination"
   replace_text "$destination" "toolpath" "$toolpath" "user" "$targetuser"
   runuser -l $targetuser -c "systemctl --user daemon-reload"
   runuser -l $targetuser -c "systemctl --user enable $filename"
   runuser -l $targetuser -c "systemctl --user restart $filename"

   # Copy Systemd Timer File
   filename="podman-setup-service-autostart.timer"
   destination="$systemdconfigdir/$filename"
   cp "systemd/timers/$filename" "$destination"
   chmod +x "$destination"
   replace_text "$destination" "toolpath" "$toolpath" "user" "$targetuser"
   runuser -l $targetuser -c "systemctl --user daemon-reload"
   runuser -l $targetuser -c "systemctl --user enable $filename"
   runuser -l $targetuser -c "systemctl --user restart $filename"
else
   #echo "Scheduling Mode <$schedulemode> is NOT supported. Possible choices are <cron> or <systemd>. Aborting !"
   schedule_mode_not_supported "$schedulemode"
fi
