#!/bin/bash

# Save current pwd
currentpath=$(pwd)

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load functions
source ${toolpath}/functions.sh

# Define user
user=${1}
if [[ -v user ]]
then
   user=$(whoami)
fi

# Get user homedir
userhomedir=$(get_homedir "${user}")

# Systemd based Distribution
if [[ $(command -v systemctl) ]]
then
    # Get Systemdconfigdir
    systemdconfigdir=$(get_systemdconfigdir "${user}")

    # Restart Systemd Container Services
    cd ${systemdconfigdir} || exit
    for service in container-*.service
    do
        # Get Service Name (without Path or "./")
        servicename=$(basename "${service}")

        # Start container
        systemd_start "${user}" "${servicename}"
    done

    # Get Quadlets Generators Folder
    quadlets_generators_path=$(get_quadlets_generators_dir "${user}")

    # List Services that are configured to automatically start
    mapfile -t services < <( find "${quadlets_generators_path}" -iwholename *.service )

    # Reload Systemd Daemon
    systemd_reload "${user}"

    # Loop over each Service
    for service in "${services[@]}"
    do
        # Get only the Basename
        servicename=$(basename "${service}")

        # Echo
        echo "Processing Service File ${service} for Service Unit ${servicename}"

        # Need to use direct Call since it's not a normal Service
        quadlet_start "${user}" "${servicename}"
    done

fi

# Change back to currentpath
cd ${currentpath} || exit

# Stop Podman "standalone" Containers
mapfile -t list < <( podman ps --all --format="{{.Names}}" )
for container in "${list[@]}"
do
    # Start Container
    podman start ${container}
done
