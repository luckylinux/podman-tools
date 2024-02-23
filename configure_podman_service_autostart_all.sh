#!/bin/bash

# List Containers
mapfile -t list < <( podman ps --all --format="{{.Names}}" )

for container in "${list[@]}"
do
   echo "Generate & Enable & Start Systemd Autostart Service for <${container}>"

   # Define where service file would be located
   servicename="container-${container}"
   servicepath="$HOME/.config/systemd/user/${servicename}.service"

   if [[ -f "${servicepath}" ]]
   then
       # Update Service File if Required
       podman generate systemd --name $container --new > $servicepath

       # Reload Systemd Configuration
       systemctl --user daemon-reload
   else
       # Generate New Service File
       podman generate systemd --name $container --new > $servicepath

       # Enable & Restart Service
       systemctl --user daemon-reload
       systemctl --user enable $servicename
       systemctl --user restart $servicename
   fi
done
