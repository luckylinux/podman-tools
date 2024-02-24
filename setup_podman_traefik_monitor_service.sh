#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load functions
source $toolpath/functions.sh

# Define user
user=${1]
if [[ -z user ]]
then
   user=$(whoami)
fi

# Define mode
if [[ ! -v schedulemode ]]
then
   schedulemode=${2:-'cron'}
fi

# Get user home folder
userhomedir=$( getent passwd "$user" | cut -d: -f6 )

# Get Systemd Config Folder
systemdconfigfolder=$( get_systemdconfigfolder "$user" )

# Echo
echo "Setup Traefik Monitoring Service for User <$user>"

# Copy Traefik Monitoring Script to Podman User Folder
mkdir -p $userhomedir/bin
cp $toolpath/bin/monitor-traefik.sh $userhomedir/bin/monitor-traefik.sh
chown -R $user:$user $userhomedir/bin/monitor-traefik.sh

# Give Script Execution Permissions
chmod +x $userhomedir/bin/monitor-traefik.sh

# Echo
echo "Installing Systemd Service file in <$userhomedir/.config/systemd/user/monitor-traefik.service>"

# Copy Traefik Monitoring Service File to Podman Systemd Service Folder
cp $toolpath/systemd/services/monitor-traefik.service $systemdconfigfolder/monitor-traefik.service
chown $user:$user $systemdconfigfolder/monitor-traefik.service

# Enable & Start Systemd file
systemd_reload_enable "$user" "$service"
