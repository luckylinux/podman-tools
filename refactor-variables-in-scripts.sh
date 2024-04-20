#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Define test folder
testfolder="test"

# Remove existing Test Folder
rm -rf "${toolpath}/${testfolder}/*"

# Create Test folder if not exist
mkdir -p "${toolpath}/${testfolder}"

# Get list of Script Files
mapfile -t scriptfiles < <( find . -iname "*.sh" | grep -v "/${testfolder}/" | grep -v "$(basename $0)" )

# Load Shell Script Helpers
source "${toolpath}/check-script.sh"

# Iterate over Files
for scriptfile in "${scriptfiles[@]}"
do
   # Exclude ./ at the start of the filename
   scriptfile=$(echo "${scriptfile}" | sed -E "s|\./(.+)$|\1|g")

   # Get Subfolder Name if it's a Subfolder
   subfolder=$(dirname "${scriptfile}")

   # Creeate Subfolder if not Exist
   if [[ -n "${subfolder}" ]]
   then
      mkdir -p "${testfolder}/${subfolder}"
   fi

   # Add some Separator Text
   #add_section "Processing File ${scriptfile}"

   # Dry Run
   cat "${scriptfile}" | sed -E 's|\$([a-zA-Z0-9]+)|\${\1\}|g' > "${testfolder}/${scriptfile}"

   # Check for Errors using ShellCheck
   check_script "${testfolder}/${scriptfile}"

   # Perform Replacement for Real
   #sed -Ei 's|\$([a-zA-Z0-9]+)|\$\{\1\}|g' "${scriptfile}"
done
