#!/bin/bash

# Old Prefix
oldprefix="~/"

# New Base Folder
newbasefolder="${HOME}/containers"

# New Compose Folder
newcomposefolder="${newbasefolder}/compose"

# Match Folders Bind Mount
mapfile -t list < <( ls -1 "${newbasefolder}" )

# Build Search String
lookfor=""
for item in "${list[@]}"
do
   lookfor="${lookfor}${oldbasefolder}${item}|"
done

# Remove last |
lookfor=$(echo "$lookfor" | sed -E 's:\|*$::' )

# Run Command
mapfile -t files < <( grep -l -r -E "${lookfor}" "${newbasefolder}/compose" )

# Join them by "\n"
# Set the internal field separator to the tab character.
IFS=$'\n';

echo "${files[*]}"
