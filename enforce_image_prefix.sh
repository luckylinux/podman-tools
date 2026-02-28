#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing "${scriptpath}/${relativepath}"); fi

# Load Configuration
# shellcheck source=./config.sh
source "${toolpath}/config.sh"

# Load Functions
source "${toolpath}/functions.sh"

# Try to get Image Prefix from Command Line Argument
image_prefix=$1

if [[ -z "${image_prefix}" ]]
then
    # Ask User Interactivelz
    read -p "Enter Docker Image Prefix Host: " image_prefix
fi

# Define User
if [[ -z "${user}" ]]
then
   user=$(whoami)
fi

# Get Containers Directory
containersdir=$(get_containers_root_default_path "${user}")

# Echo
echo "Containers Folder: ${containersdir}"

# Change Working Directory to Quadlets Folder
cd "${containersdir}/quadlets"

# Get all Matches that do NOT have the Image configured as it should be
# find . -iwholename "./*.container" | xargs -n1 cat | grep -E "^Image=" | grep -v "${image_prefix}"

# Get a list of all Container Files
mapfile -t container_files < <(find . -iwholename "./*.container")

# Loop over Results
for container_file in "${container_files[@]}"
do
    # Get only basename
    container_file_name=$(basename "${container_file}")

    # Get full Path
    container_file_path=$(realpath --canonicalize-missing "${container_file}")

    # Echo
    echo "Processing Container File ${container_file_path}"

    # Check Image Directive
    image_directive_old=$(cat "${container_file_path}" | grep -E "^Image=")

    # Get old Image Source (current)
    image_source_old=$(echo "${image_directive_old}" | sed -E "s|^Image=([a-z0-9/:\.]+)|\1|")

    # Echo
    echo -e "\tImage Directive: ${image_directive_old}"
    echo -e "\tImage Source: ${image_source_old}"

    # Check if Image Source already starts with ${image_prefix}
    if [[ "${image_source_old}" == "${image_prefix}/"* ]]
    then
        # Nothing to do
        echo -e "\tNothing to do. Image prefix is already implemented"
    elif [[ "${image_source_old}" == "localhost/"* ]]
    then
        # Nothing to do
        echo -e "\tNothing to do. Image is local and therefore should not be prefixed"
    else
        # Determine new Image
        image_source_new="${image_prefix}/${image_source_old}"

        # Determine new Image Directive
        image_directive_new="Image=${image_source_new}"

        # Echo
        echo -e "\tAdd Prefix to current Image:"
        echo -e "\t\tOld Image Source: ${image_source_old}"
        echo -e "\t\tNew Image Source: ${image_source_new}"
        echo -e "\t\tOld Image Directive: ${image_directive_old}"
        echo -e "\t\tNew Image Directive: ${image_directive_new}"


        # Add Image Prefix before existing URL
        sed -Ei "s|^${image_directive_old}|${image_directive_new}|g" "${container_file_path}"
    fi
done
