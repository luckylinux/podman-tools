#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing "${scriptpath}/${relativepath}"); fi

# Load Configuration
# shellcheck source=./config.sh
source "${toolpath}/config.sh"

# Load Functions
source "${toolpath}/functions.sh"

# Define Pod
podname="$1"
if [[ -z "${podname}" ]]
then
    read -p "Enter the Pod Name to Archive: " podname
fi

# Define user
if [[ ! -v user ]]
then
    user=$(whoami)
fi

# Stop Pod using Systemd
# This fails since it doesn't keep generators into account
# systemd_stop "${user}" "${podname}-pod.service"

quadlet_stop "${user}" "${podname}-pod.service"


# Get containersdir
containersdir=$(get_containers_root_default_path "${user}")

# Generate Timestamp for backup archive
timestamp=$(date +"%Y%m%d-%H%M%S")

# Become "root" in order to have sufficient Privileges to handle subuids/subgids
# Find all Folders that Match Pod Storage Pattern
# mapfile -t used_folders < <(bash -c "podman unshare find \"${containersdir}\"/{cache,certificates,compose,config,data,log,quadlets,secrets} -maxdepth 1 -type d -iwholename \"*/${podname}*\" 2> /dev/null")

# Debug
# echo "Archiving the following Folders":
# for used_folder in "${used_folders[@]}"
#do
#    echo -e "\t${used_folder}"
# done

# Debug
# echo "Archive Command:"
# echo "tar cvfz \"${containersdir}/${podname}-${timestamp}.tar.gz\" ${used_folders[@]}"

# Become "root" in order to have sufficient Privileges to handle subuids/subgids
# Create Archive
# podman unshare bash -c "tar cvfz \"${containersdir}/${podname}-${timestamp}.tar.gz\" ${used_folders[@]}"



# Become "root" in order to have sufficient Privileges to handle subuids/subgids
# Then execute Script
podman unshare ./archive_pod_unshared.sh "${podname}"
