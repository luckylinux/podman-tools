#!/bin/bash

# Tools Path
toolspath=$(dirname $0)

# Copy Traefik Monitoring Script to Podman User Folder
mkdir -p ~/bin
cp $toolspath/bin/monitor-traefik.sh ~/bin/monitor-traefik.sh

# Give Script Execution Permissions
chmod +x ~/bin/monitor-traefik.sh

# Copy Traefik Monitoring Service File to Podman Systemd Service Folder
cp $toolspath/systemd/services/monitor-traefik.service ~/.config/systemd/user/monitor-traefik.service

# Reload Systemd Service Files
systemctl --user daemon-reload

# Enable the Service to start automatically at each boot
systemctl --user enable monitor-traefik.service

# Start the Service
systemctl --user restart monitor-traefik.service

# Verify the Status is OK
systemctl --user status monitor-traefik.service

# Check the logs from time to time and in case of issues
journalctl --user -xeu monitor-traefik.service
