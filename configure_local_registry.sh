#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Configuration
source ${toolpath}/config.sh

# Load Functions
source ${toolpath}/functions.sh

# User Name
user="${1}"
#user=${1-"podman"}

# Localmirror
localmirror=${2-""}

if [[ -z "${localmirror}" ]]
then
   read -p "Enter Docker Local Mirror FQDN: " localmirror
   echo -e "\n"
fi

# Home Directory
homedir=$(get_homedir "${user}")

# Fix short-aliases in ${homedir}/.cache/containers/short-name-aliases.conf
sed -Ei "s|^(\s*)\"(.*)\"\s*?=\s*?\"docker\.io/(.*)\"(.*)$|\1\"\2\" = \"${localmirror}/\3\"\4|g" "${homedir}/.cache/containers/short-name-aliases.conf"

# sed -Ei "s|^(\s*)\"(.*)\"\s*?=\s*?\"(.*)\"(.*)$|\1\"\2\" = \"\3\"\4|g" "${homedir}/.cache/containers/short-name-aliases.conf"
