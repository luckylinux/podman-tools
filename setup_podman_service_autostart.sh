#!/bin/bash

# List Containers
podman ps --all

# Ask user input
read -p "Container Name to Create Systemd Service for:" name

# Generate Service File
podman generate systemd --name $name --new > ~/.config/systemd/user/container-$name.service

# Enable & Restart Service
systemctl --user daemon-reload
systemctl --user enable container-$name
systemctl --user restart container-$name
