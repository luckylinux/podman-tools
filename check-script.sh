#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Include Functions
source "${toolpath}/functions.sh"

# Unset External Options to make sure we have a Clean Configuration to Start With
unset SHELLCHECK_OPTS

# Script File to check
scriptfile=${1-""}

# Define MINIMUM Severity Level to Check
# Options are: error, warning, info, style
severity="warning"

check_script() {
   # File to Check
   local lscriptfile=${1-""}

   # Ask User Interactively if not set
   if [[ -z "${lscriptfile}" ]]
   then
       read -p "Enter the Script File Path to check: " lscriptfile
   fi

   # Perform Check using ShellCheck (if File Exists)
   if [[ -f "${lscriptfile}" ]]
   then
      shellcheck --check-sourced --color=always --source-path="${toolpath}" --shell=bash --severity="${severity}" "${lscriptfile}"
   fi
}

# Check All
check_all() {
   # Path to Check for all containing Script Files
   # Default to ${toolpath}
   local lsearchpath=${1-"${toolpath}"}

   ## Get list of Script Files
   mapfile -t scriptfiles < <( find "${lsearchpath}" -iname "*.sh" | grep -v "$(basename ${0})" )

   # Check each File
   for scriptfile in "${scriptfiles[@]}"
   do
       # Check File
       check_script "${scriptfile}"
   done
}

# If script is Executed (NOT sourced) then execute a "main" function
if [ "${BASH_SOURCE[0]}" -ef "$0" ]
then
    check_script "$1"
fi
