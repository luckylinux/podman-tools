#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Configuration
# shellcheck source=./config.sh
source ${toolpath}/config.sh

# Load Functions
source ${toolpath}/functions.sh

# Create file /etc/rc.local if it doesn't exist yet
if [ ! -f /etc/rc.local ]
then
    cp ${toolpath}/etc/rc.local /etc/rc.local
fi

# Make it executable
chmod +x /etc/rc.local

# Systemd based Distribution
if [[ $(command -v systemctl) ]]
then
    # Create Systemd service to enable /etc/rc.local
    cp ${toolpath}/systemd/services/rc-local.service /etc/systemd/system/rc-local.service

    # Reload Systemd Daemon
    systemctl daemon-reload

    # Enable & start service
    systemctl enable rc-local
    systemctl start rc-local.service
    systemctl status rc-local.service
else
    # Nothing currently implemented for OpenRC
    echo "[WARNING] Currently rc-local is NOT implemented for OpenRC based Distributions"

    # Dummy Variable
    x=1
fi
