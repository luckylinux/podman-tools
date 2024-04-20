# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Functions
source ${toolpath}/functions.sh

# Update Tools from anywhere
update_tools() {
   # The User is passed as Optional Argument
   local luser=${1-""}
   if [[ -z "${luser}" ]]
   then
      luser=$(whoami)
   fi

   # Save Current Directory
   currentpath=$(pwd)

   # Change Directory to Toolpath
   cd ${toolpath} || exit

   # Do a git pull
   generic_cmd "${luser}" "git" "pull"

   # Reload ~/.bash_profile
   homedir=$(get_homedir "${luser}")
   generic_cmd "${luser}" "source" "${homedir}/.bash_profile"

   # Go back to Current Path
   cd ${currentpath} || exit
}
