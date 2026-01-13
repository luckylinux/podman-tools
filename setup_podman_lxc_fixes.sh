#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Configuration
# shellcheck source=./config.sh
source ${toolpath}/config.sh

# Load Functions
source ${toolpath}/functions.sh

# Check to make sure that we are running inside LXC Container
grep -qa container=lxc /proc/1/environ
status=$?

# Define Service Name
servicename="podman-lxc-fixes"

if [ ${status} -eq 0 ]
then
    # Echo
    echo "Running in LXC"

    # Copy Script
    cp "${toolpath}/usr/local/sbin/podman-lxc-fixes.sh" "/usr/local/sbin/podman-lxc-fixes.sh"

    # Systemd based Distribution
    if [[ $(command -v systemctl) ]]
    then
        # Copy Systemd Service
        cp "${toolpath}/etc/systemd/system/${servicename}.service" "/etc/systemd/system/${servicename}.service"

        # Copy Systemd Timer
        cp "${toolpath}/etc/systemd/system/${servicename}.timer" "/etc/systemd/system/${servicename}.timer"

        # Reload Systemd Daemon
        systemctl daemon-reload

        # Enable Systemd Timer
        systemctl enable "${servicename}"

        # Start Systemd Timer
        systemctl restart "${servicename}"
    else
        # Nothing currently implemented for OpenRC
        echo "[WARNING] Currently ${servicename} is NOT implemented for OpenRC based Distributions"
    fi
else
    # Echo
    echo "NOT running in LXC"
fi
