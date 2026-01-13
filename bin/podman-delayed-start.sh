#!/bin/bash

# Determine toolpath if not set already
relativepath="../" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Functions
source ${toolpath}/functions.sh

# Get User ID
uid=$(id -u)

# Get User
user=$(whoami)

# Wait a bit
sleep 15

# Reload Systemd Daemon
systemd_daemon_reload

# Rexecute Systemd Daemon
systemctl_daemon_reexec

# List Services that are configured to automatically start
mapfile -t services < <( find /var/run/user/${uid}/systemd/generator/default.target.wants/ -iwholename *.service )

# Reload Systemd Daemon
systemd_reload

# Loop over each Service
for service in "${services[@]}"
do
    # Get only the Basename
    servicename=$(basename "${service}")

    # Echo
    echo "Processing Service File ${service} for Service Unit ${servicename}"

    # Need to use direct Call since it's not a normal Service
    systemd_restart "${servicename}"
done
