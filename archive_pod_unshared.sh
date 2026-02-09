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

# Define user
if [[ ! -v user ]]
then
    # user=$(whoami)
    user="${USER}"
fi

# Debug
# echo "User: ${USER}"
# echo "User: ${user}"

# Get containersdir
containersdir=$(get_containers_root_default_path "${user}")

# Debug
echo "Containers Directory: ${containersdir}"

# Generate Timestamp for backup archive
timestamp=$(date +"%Y%m%d-%H%M%S")

# Become "root" in order to have sufficient Privileges to handle subuids/subgids

# Change Folder to containersdir'
cd "${containersdir}"

# Find all Folders that Match Pod Storage Pattern
mapfile -t used_folders < <(find ./{cache,certificates,compose,config,data,log,quadlets,secrets,volumes} -maxdepth 1 -type d -iwholename "*/${podname}*" 2> /dev/null)

# Debug
echo "Archiving the following Folders":
for used_folder in "${used_folders[@]}"
do
    echo -e "\t${used_folder}"
done

# Debug
echo "Archive Command:"
echo "tar cvfz \"${containersdir}/${podname}-${timestamp}.tar.gz\" ${used_folders[@]}"

# Create Archive
tar cvfz "${containersdir}/${podname}-${timestamp}.tar.gz" ${used_folders[@]}

# Move all Folders to Archive
# ...
