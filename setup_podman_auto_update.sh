#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Create CRON file
tee /etc/cron.d/podman-auto-update << EOF
SHELL=/bin/bash
0 0 * * * podman bash $toolpath/update_podman_containers.sh

EOF

# Make it executable
chmod +x /etc/cron.d/podman-auto-update

# Copy CRON file
#cp cron/podman-auto-update /etc/cron.d/podman-auto-update
