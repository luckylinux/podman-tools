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
status=$(grep -qa container=lxc /proc/1/environ)

if [ ${status} -eq 0]
then
    # Echo
    echo "Running in LXC"

    # Copy Script
    cp ${toolpath}/usr/local/sbin/podman-lxc-fixes.sh /usr/local/sbin/podman-lxc-fixes.sh

    # Copy Systemd Service
    cp ${toolpath}/etc/systemd/system/podman-lxc-fixes.service /etc/systemd/system/podman-lxc-fixes.service

    # Copy Systemd Timer
    cp ${toolpath}/etc/systemd/system/podman-lxc-fixes.timer /etc/systemd/system/podman-lxc-fixes.timer

    # Reload Systemd Daemon
    systemctl daemon-reload

    # Enable Systemd Timer
    systemctl enable podman-lxc-fixes

    # Start Systemd Timer
    systemctl restart podman-lxc-fixes
else
    # Echo
    echo "NOT running in LXC"
fi
