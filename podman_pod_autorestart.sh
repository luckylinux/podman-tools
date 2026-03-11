#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load functions
source ${toolpath}/functions.sh

# Define user
if [[ ! -v user ]]
then
   user=$(whoami)
fi

# Define Pod Name as the first Input Argument
podname="$1"

# Define Action as the second Input Argument
action="$2"

if [[ "${action}" == "start" ]]
then
    # Echo
    echo -e "Trigger restart of Podman Pod <${podname}>"

    # Echo
    echo -e "Reloading Systemd"

    # Reload Systemd
    systemctl --user daemon-reload

    # Reset all relevant Failed Services
    systemctl --user reset-failed ${podname}-*.service

    # Wait a bit
    sleep 5

    # Restart Pod
    systemctl --user restart ${podname}-pod.service
elif [[ "${action}" == "stop" ]]
then
    # Echo
    echo -e "Stopping auxiliary Systemd Unit podman-pod-autorestart@${podname}.service (no Action performed)"
fi
