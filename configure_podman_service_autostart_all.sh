#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Load Configuration
source $toolpath/config.sh

# Load Functions
source $toolpath/functions.sh

# Setting
setting=${1-"enable"}

# User
user=${2-""}
if [[ -z "$user" ]]
then
   user=$(whoami)
fi

# Get homedir
homedir=$(get_homedir "${user}")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "${user}")

# Validation
if [ "$setting" != "enable" ] && [ "$setting" != "disable" ]
then
   echo "Setting must be one of the following: <enable> or <disable>. Aborting."
   exit 9
fi

if [ "$setting" == "enable" ]
then
   # List running Containers
   mapfile -t list < <( podman ps --all --format="{{.Names}}" )

   for container in "${list[@]}"
   do
      # Echo
      echo "Generate & Enable & Start Systemd Autostart Service for <${container}>"

      # Define where service file would be located
      servicename="container-${container}"
      servicepath="$HOME/.config/systemd/user/${servicename}.service"

      if [[ -f "${servicepath}" ]]
      then
          # Update Service File if Required
          podman generate systemd --name $container --new > $servicepath

          # Reload Systemd Configuration
          systemd_reload "${user}"
      else
          # Generate New Service File
          podman generate systemd --name $container --new > $servicepath

          # Enable & Restart Service
          systemd_reload "${user}"
          systemd_enable "${user}" "${servicename}"
          systemd_restart "${user}" "${servicename}"
      fi
   done
else
    # List Systemd Services
    mapfile -t list < <( ls -1 ${systemdconfigdir}/container-* )

    # Stop These Services which might be deprecated anyways
    for servicepath in "${list[@]}"
    do
       # Need only the basename
       service=$(basename ${servicepath})

       # Echo
       echo "Disable & Stop & Remove Systemd Autostart Service <${container}>"

       # Disable Service
       systemd_disable "${user}" "${service}"

       # Stop Service
       systemd_stop "${user}" "${service}"

       # Remove Service
       rm -f $servicepath

       # Reload Systemd Daemon
       systemd_reload "${user}"
    done
fi
