#!/bin/bash

###################################################
## IMPORTANT: THIS FILE MUST BE RUN **MANUALLY** ##
###################################################

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load functions
source ${toolpath}/functions.sh

# Define user
if [[ ! -v user ]]
then
#   user=${1:-"podman"}
   user=$(whoami)
fi

# Define mode
if [[ ! -v schedulemode ]]
then
#   schedulemode=${2:-"cron"}
   schedulemode="systemd"
fi

# Get homedir
homedir=$(get_homedir "${user}")

# Systemd based Distribution
if [[ $(command -v systemctl) ]]
then
    # Nothing to do
    x=1
else
    # Systemd is not available
    # Force Cron
    schedulemode="cron"
fi

# Systemd based Distribution
if [[ $(command -v systemctl) ]]
then
    # Get Systemdconfigdir
    systemdconfigdir=$(get_systemdconfigdir "${user}")
fi

# Change to Home Folder
cd ${HOME} || exit

# Setup venv for Podman Compose
generic_cmd "${user}" -- bash << EOF
python3 -m venv ${HOME}/podman-compose;
source ${HOME}/podman-compose/bin/activate;
pip install --upgrade pip;
pip install --upgrade git+https://github.com/containers/podman-compose.git@v1.5.0
EOF

# This Command works on Alpine Linux
# sudo -u podman -i bash -c "python3 -m venv \${HOME}/podman-compose ; source \${HOME}/podman-compose/bin/activate ; pip install --upgrade pip ; pip install --upgrade git+https://github.com/containers/podman-compose.git@v1.5.0"
