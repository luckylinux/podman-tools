#!/bin/bash

# Attempt to use Argument for Container Name
name=${1-""}

# Ask user input if Container Name was not Provided
if [[ -n "$name" ]]
then
   # List Containers
   podman ps --all

   # Ask User Input
   read -p "Container Name to Create Systemd Service for:" name
fi

# Generate Service File
podman generate systemd --name $name --new > ~/.config/systemd/user/container-$name.service

# Enable & Restart Service
systemctl --user daemon-reload
systemctl --user enable container-$name
systemctl --user restart container-$name
