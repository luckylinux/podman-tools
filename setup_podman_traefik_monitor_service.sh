#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Define user
user=${1:-'podman'}

# Get user home folder
userhomedir=$( getent passwd "$user" | cut -d: -f6 )

# Echo
echo "Setup Traefik Monitoring Service for User <$user>"

# Copy Traefik Monitoring Script to Podman User Folder
mkdir -p ~/bin
cp $toolpath/bin/monitor-traefik.sh $userhomedir/bin/monitor-traefik.sh

# Give Script Execution Permissions
chmod +x $userhomedir/bin/monitor-traefik.sh

# Echo
echo "Installing Systemd Service file in <$userhomedir/.config/systemd/user/monitor-traefik.service>"

# Copy Traefik Monitoring Service File to Podman Systemd Service Folder
cp $toolpath/systemd/services/monitor-traefik.service $userhomedir/.config/systemd/user/monitor-traefik.service

# Reload Systemd Service Files
runuser -l $user -c "systemctl --user daemon-reload"

# Enable the Service to start automatically at each boot
runuser -l $user -c "systemctl --user enable monitor-traefik.service"

# Start the Service
runuser -l $user -c "systemctl --user restart monitor-traefik.service"

# Verify the Status is OK
runuser -l $user -c "systemctl --user status monitor-traefik.service"

# Check the logs from time to time and in case of issues
runuser -l $user -c "journalctl --user -xeu monitor-traefik.service"
