#!/bin/bash

# Test BASH Variable Expansion
#test_expansion() {
#  local ltest1="${@:2}"
#  local ltest2="${*:2}"
#
#  echo ${ltest1}
#  echo ${ltest2}
#}

# Repeat Character N times
repeat_character() {
   # Character to repeat
   local lcharacter=${1}

   # Number of Repetitions
   local lrepetitions=${2}

   # Print using Brace Expansion
   #for i in {1 ... ${lrepetitions}}
   for i in $(seq 1 1 ${lrepetitions})
   do
       echo -n "${lcharacter}"
   done
}

# Add Line Separator
add_separator() {
   local lcharacter=${1-"#"}
   local lrows=${2-"1"}

   # Get width of Terminal
   local lwidth=$(tput cols)

   # Repeat Character
   for r in $(seq 1 1 ${lrows})
   do
      repeat_character "${lcharacter}" "${lwidth}"
   done
}

# Add Line Separator with Description
add_section() {
   local lcharacter=${1-"#"}
   local lrows=${2-"1"}
   local ldescription=${3-""}

   # Determine number of Separators BEFORE and AFTER the Description
   #local lrowsseparatorsbefore=$(echo "${lrows-1} / ( 2 )" | bc -l)
   #local lrowsseparatorafter="${lrowsseparatorsbefore}"
   local lrowsbefore="${lrows}"
   local lrowsafter="${lrows}"

   # Add Separator
   add_separator "${lcharacter}" "${lrowsbefore}"

   # Add Header with Description
   add_description "${lcharacter}" "${ldescription}"

   # Add Separator
   add_separator "${lcharacter}" "${lrowsafter}"
}

add_description() {
   # User Inputs
   local lcharacter=${1-"#"}
   local ldescription=${2-""}

   # Add one Space before and after the original String
   ldescription=" ${ldescription} "

   # Get width of Terminal
   local lwidth=$(tput cols)

   # Get length of Description
   local llengthdescription=${#ldescription}

   # Get width of Terminal
   local lwidth=$(tput cols)

   # Subtract Description from Terminal Width
   local llengthseparator=$((lwidth - llengthdescription))

   # Divide by two
   local llengtheachseparator=$(echo "${llengthseparator} / ( 2 )" | bc -l)

   # Remainer
   local lremainer=$((llengthseparator % 2))
   local lextrastr=$(repeat_character "${lcharacter}" "${lremainer}")

   # Get String of Characters for BEFORE and AFTER the Description
   local lseparator=$(repeat_character "${lcharacter}" "${llengtheachseparator}")

   # Print Description Line
   echo "${lseparator}${ldescription}${lextrastr}${lseparator}"
}

# Check if Array Contains Element
array_contains() {
    local larr=${1}
    local lsearch=${2}

    # Initialize Return Status
    local lstatus=0

    # Loop over elements
    local litem=""
    for litem in "${larr[@]}"
    do
        if [[ "${litem}" == "${lsearch}" ]]
        then
            # Found it
            lstatus=1
        fi
    done

    # Return Status
    echo lstatus
}

# Replace Text in Template
replace_text() {
    local lfilepath=${1}
    local lnargin=$#
    local lnparameters=$(($((${lnargin}-1)) / 2))
    local lARGV=("$@")
    #Debug
    #echo "Passed ${lnargin} arguments and ${lnparameters} parameter"

    # Initialize Variables
    local p=1

    for ((p=1;p<=${lnparameters};p++))
    do
        local liname=$((2*p-1))
        local livalue=$((${liname}+1))
        local lname=${lARGV[${liname}]}
        local lvalue=${lARGV[${livalue}]}

        # Debug
        #echo "Replace {{${lname}}} -> ${lvalue} in ${lfilepath}"

        # Execute Replacement
        sed -Ei "s|\{\{${lname}\}\}|${lvalue}|g" "${lfilepath}"
    done
}

# Schedule Mode is NOT Supported
schedule_mode_not_supported() {
   local lschedulemode=${1}
   echo "Scheduling Mode <${lschedulemode}> is NOT supported. Possible choices are <cron> or <systemd>. Aborting !"
   exit 2
}

# Get Homedir
get_homedir() {
   local luser=${1}

   # Get homedir
   local lhomedir=$(getent passwd "${luser}" | cut -d: -f6)

   # Return result
   echo ${lhomedir}
}

# Get Systemdconfig
get_systemdconfigdir() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}

   if [[ "${luser}" == "root" ]]
   then
       local lsystemdconfigdir="/etc/systemd/system"
   else
       local luserhomedir=$(get_homedir "${luser}")
       local lsystemdconfigdir="${luserhomedir}/.config/systemd/user"
   fi

   # Make sure to create it if not existing already
   if [[ ! -d "${lsystemdconfigdir}" ]]
   then
       mkdir -p "${lsystemdconfigdir}"
   fi

   # Return result
   echo ${lsystemdconfigdir}
}


# Execute Systemd Command
generic_cmd() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lcommand=${2}

   # When used with Systemd: Arguments includes "action", possible options, "service" (e.g. systemd <status> <container-test.service>)
   local larguments="${@:3}"

   local lexecutingUser=$(whoami)

   if [[ "${luser}" == "root" ]]
   then
      # Run without runuser and without --user

      # Run Command System-Wide
      ${lcommand} ${larguments}
   else
      if [[ "${lexecutingUser}" == "root" ]]
      then
          # Run with runuser and with --user

          # Run Command as root user and target a different non-root User
          runuser -l ${luser} -c ${lcommand} ${larguments}
      elif [[ "${luser}" == "${lexecutingUser}" ]]
      then
          # Run without runuser and with --user

          # Run Systemd Command directly with --user Option (target user is the same as the user that is executing the script / function)
          ${lcommand} ${larguments}
      fi
   fi
}

# Execute Systemd Command
systemd_cmd() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local laction=${2}
   local lservice=${3}
   #local loptions=${*:2} # Old
   local loptions=${*:4} # New

   # Who is executing the Script
   local lexecutingUser=$(whoami)

   # Debug
   #echo "Execute systemd command targeting user <${luser}> with action <${laction}> for service <${lservice}>"

   if [[ "${luser}" == "root" ]]
   then
      # Run without runuser and without --user

      # Run Command System-Wide
      systemctl ${laction} ${lservice} ${loptions}
   else
      if [[ "${lexecutingUser}" == "root" ]]
      then
          # Run with runuser and with --user

          # Run Command as root user and target a different non-root User
          runuser -l "${luser}" -c "systemctl --user ${laction} ${lservice}" "${loptions}"
      elif [[ "${luser}" == "${lexecutingUser}" ]]
      then
          # Run without runuser and with --user

          # Run Systemd Command directly with --user Option (target user is the same as the user that is executing the script / function)
          systemctl --user ${laction} ${lservice} ${loptions}
      fi
   fi
}


# Execute Systemd Command
journald_cmd() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local laction=${2}
   local lservice=${3}
   #local loptions=${*:2} # Old
   local loptions=${*:2}  # New

   # Who is executing the Script
   local lexecutingUser=$(whoami)

   # Debug
   #echo "Execute journald command targeting user <${luser}> with action <${laction}> for service <${lservice}>"

   if [[ "${luser}" == "root" ]]
   then
      # Run without runuser and without --user

      # Run Command System-Wide
      journalctl "${laction}" "${lservice}" ${loptions}
   else
      if [[ "${lexecutingUser}" == "root" ]]
      then
          # Run with runuser and with --user

          # Run Command as root user and target a different non-root User
          runuser -l ${luser} -c "journalctl --user \"${laction}\" \"${lservice}\"" ${loptions}
      elif [[ "${luser}" == "${lexecutingUser}" ]]
      then
          # Run without runuser and with --user

          # Run Systemd Command directly with --user Option (target user is the same as the user that is executing the script / function)
          journalctl --user "${laction}" "${lservice}" ${loptions}
      fi
   fi
}


# Enable service(s)
systemd_enable() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   # Run Command using Wrapper
   systemd_cmd "${luser}" "enable" "${lservice}"
}

# Disable service(s)
systemd_disable() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   # Run Command using Wrapper
   systemd_cmd "${luser}" "disable" "${lservice}"
}

# Status of service(s)
systemd_status() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   # Run Command using Wrapper
   systemd_cmd "${luser}" "status" "${lservice}" --no-pager
}

systemd_restart() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   # Run Command using Wrapper
   systemd_cmd "${luser}" "restart" "${lservice}"
}

systemd_stop() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   # Run Command using Wrapper
   systemd_cmd "${luser}" "stop" "${lservice}"
}

systemd_start() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   # Run Command using Wrapper
   systemd_cmd "${luser}" "start" "${lservice}"
}

systemd_reload() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   if [[ -z "${lservice}" ]]
   then
      # Just run systemd_daemon_reload since no service was specified
      systemd_daemon_reload "${luser}"
   else
      # Check if Service provides a <reload> method
      local lcanreload=$(systemctl show "${lservice}" --property=CanReload --value)

      if [[ "${lcanreload}" == "yes" ]]
      then
          # If yes, execute reload of the service only
          # Run Command using Wrapper
          systemd_cmd "${luser}" "reload" "${lservice}"

          # Also Reset Errors for that Service
          systemd_reset "${luser}" "${lservice}"
      else
          # Just run systemd_daemon_reload since the service doesn't provide a <reload> method
          systemd_daemon_reload "${luser}"
      fi
   fi
}

systemd_reset() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   # Run Command using Wrapper
   systemd_cmd "${luser}" "reset-failed" "${lservice}"
}

systemd_daemon_reload() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}

   # Run Command using Wrapper
   systemd_cmd "${luser}" "daemon-reload"
}

systemd_daemon_reexec() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}

   # Run Command using Wrapper
   systemd_cmd "${luser}" "daemon-reexec"
}



journald_log() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   #  Run Command using Wrapper
   journald_cmd "${luser}" "-xeu" "${lservice}"
}

# Shortcut to Systemd daemon-reload + enable + restart service
systemd_reload_enable() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local luser=${1}
   local lservice=${2}

   # Reload Systemd Service Files
   sleep 0.5
   systemd_reload "${luser}" "${lservice}"
   sleep 0.5

   # Enable the Service to start automatically at each boot
   systemd_enable "${luser}" "${lservice}"

   # Start the Service
   systemd_restart "${luser}" "${lservice}"

   # Verify the Status is OK
   systemd_status "${luser}" "${lservice}"

   # Check the logs from time to time and in case of issues
   journald_log "${luser}" "${lservice}"
}



# List subuid / subgid
list_subuid_subgid() {
     local lSUBUID=/etc/subuid
     local lSUBGID=/etc/subgid
     local lUSERS
     local li=0

     for li in ${lSUBUID} ${lSUBGID}; do [[ -f "${li}" ]] || { echo "ERROR: ${li} does not exist, but is required."; exit 1; }; done
     [[ -n "${1}" ]] && lUSERS=${1} || lUSERS=$(awk -F : '{x=x " " ${1}} END{print x}' ${lSUBUID})
     for i in ${lUSERS}; do
        awk -F : "\${1} ~ /${li}/ {printf(\"%-16s sub-UIDs: %6d..%6d (%6d)\", \${1} \",\", \${2}, \${2}+\${3}, \${3})}" ${lSUBUID}
        awk -F : "\${1} ~ /${li}/ {printf(\", sub-GIDs: %6d..%6d (%6d)\", \${2}, \${2}+\${3}, \${3})}" ${lSUBGID}
        echo ""
     done
}

# Get Homedir
get_homedir() {
   local luser=${1}

   # Get homedir
   local lhomedir=$(getent passwd "${luser}" | cut -d: -f6)

   # Return$ result
   echo ${lhomedir}
}

# Make Mutable if Exist
make_mutable_if_exist() {
    local ltarget=${1}

    if [ -d "${ltarget}" ] || [ -f "${ltarget}" ]
    then
       # Remove the Immutable Flag
       chattr -i "${ltarget}"
    fi
}

# Make Immutable if Exist
make_immutable_if_exist() {
    local ltarget=${1}

    if [ -d "${ltarget}" ] || [ -f "${ltarget}" ]
    then
       # Add the Immutable Flag
       chattr +i "${ltarget}"
    fi
}

# Move if Exist
move_if_exist() {
    local lorigin=${1}
    local ldestination=${2}

    if [ -d "${lorigin}" ] || [ -f "${lorigin}" ]
    then
       # Move to Destination
       mv "${lorigin}" "${ldestination}"
    fi
}

# Remove empty Folder if Exist
rmdir_if_exist() {
    local ltarget=${1}

    if [ -d "${ltarget}" ]
    then
       # Attempt to remove Empty Folder
       rmdir "${ltarget}"

       # Check Return Code
       if [[ "$?" -ne 0 ]]
       then
          echo "FAILED to remove Folder <${ltarget}>. Error code of `rmdir` was $?. Possible NON-EMPTY Directory ?"
       fi
    fi
}

# Remove leading and/or trailing Slashes ("/")
remove_leading_trailing_slashes() {
    # Init Variable
    local lsanitized=${1}

    # Remove leading and trailing Slashes
    lsanitized=${lsanitized%/};
    lsanitized=${lsanitized#/}

    # Echo & Return
    echo ${lsanitized}
}

# Get Containers Associated with Compose File
get_containers_from_compose_dir() {
   # The return Array is passed by nameref
   # Reference to output array
   declare -n lreturnarray="${1}"

   # The compose Directory is passed as an Argument
   local lcomposedir=${2-""}
   if [[ -z "${lcomposedir}" ]]
   then
       lcomposedir=$(pwd)
   fi

   # Extract from the File itself:
   #mapfile list < <( grep -r -h "container_name:" "${lcomposedir}/compose.yml" | sed -E "s|^\s*?#?\s*?container_name:\s*?([a-zA-Z0-9_-]+)\s*?$|\1|g" )
   mapfile llist < <( grep -r -h "container_name:" "${lcomposedir}/compose.yml" )

   # Perform line-by-line matching using sed
   local litem=""
   local lcleanitem=""
   local lchk=""
   for litem in "${llist[@]}"
   do
       # Debug
       #echo ${litem}

       # Perfom Cleaning of the Item String
       lcleanitem=$(echo ${litem} | sed -E "s|^\s*?#?\s*?container_name:\s*?([a-zA-Z0-9_-]+)\s*?$|\1|g")

       # Debug
       #echo "Clean Item: <${lcleanitem}>"

       # Check if it's already in Array
       lchk=$(array_contains locallist "${lcleanitem}")

       # Add it to array anyways
       # Needs to be better handled in a future version
       lreturnarray+=("${lcleanitem}")

       # If Status is 0 then add to return array
       #if [[ ${lchk} -eq 0 ]]
       #then
       #    lreturnarray+=("${lcleanitem}")
       #fi
   done
}

# Get Systemd Service File from Container Name
get_systemd_file_from_container() {
    # The Container Name is passed as an Argument
    local lcontainer=${1}

    # Define Service File
    local lservicefile="container-${lcontainer}.service"

    # Return
    echo ${lservicefile}
}

# Get Container Name from Systemd Service File
get_container_from_systemd_file() {
    # The Service Name is passed as an Argument
    local lservice=${1}

    # Declare local variable
    local lcontainer=""

    # Strip "container-" from string
    lcontainer="${lservice}"
    lcontainer=${lcontainer/"container-"/""}
    lcontainer=${lcontainer/".service"/""}

    # Return
    echo ${lcontainer}
}

# Get Systemd File
#get_systemd_file_from_container() {
#    # The Container Name is passed as an Argument
#    local lname=${1}
#
#    # Extract Systemd File from Container
#    local lservicefile=$(podman inspect ${lname} | jq -r '.[0].Config.Labels."PODMAN_SYSTEMD_UNIT"')
#
#    # Return
#    echo ${lservicefile}
#}

# Get Container Compose File
get_compose_dir_from_container() {
    # The Container Name is passed as an Argument
    local lcontainer=${1}

    # Extract compodir from Container
    local lcomposedir=$(podman inspect ${lcontainer} | jq -r '.[0].Config.Labels."com.docker.compose.project.working_dir"')

    # Return
    echo ${lcomposedir}
}

compose_check_dir() {
   # Compose Directory is Current Directory
   local lcomposedir=$(pwd)

   # Check if we are really in a compose directory
   if [[ ! -f "${lcomposedir}/compose.yml" ]]
   then
       echo "ERROR: This is NOT a Compose Directory."
       echo "       File <compose.yml> could NOT be found"
       echo "ABORTING !"
       exit 99
   fi
}

# Update Compose
compose_update() {
   # Compose Directory is Current Directory
   local lcomposedir=$(pwd)

   # Compose Arguments
   local lcomposeargs=${1-"-d"}

   # Podman Arguments
   local lpodmanargs=${2-""}

   # The User is passed as Optional Argument
   local luser=${3-""}
   if [[ -z "${luser}" ]]
   then
      luser=$(whoami)
   fi

   # Check if it's a valid Compose Directory
   # Abort on Error
   set -e
   compose_check_dir
   set +e

   # Run compose_down
   compose_down "${lcomposeargs}" "${lpodmanargs}" "${luser}"

   # Run compose_up
   compose_up "${lcomposeargs}" "${lpodmanargs}" "${luser}"
}

# Compose Down
compose_down() {
   # Compose Directory is Current Directory
   local lcomposedir=$(pwd)

   # Compose Arguments
   local lcomposeargs=${1-"-d"}

   # Podman Arguments
   local lpodmanargs=${2-""}

   # The User is passed as Optional Argument
   local luser=${3-""}
   if [[ -z "${luser}" ]]
   then
      luser=$(whoami)
   fi

   # Check if it's a valid Compose Directory
   # Abort on Error
   set -e
   compose_check_dir
   set +e

   # Declare list_containers as a (global) array that we will pass to get_containers_from_compose_dir by reference
   declare -a list_containers

   # Get List of Containers Associated with Compose File by passing list_containers by reference
   get_containers_from_compose_dir list_containers "${lcomposedir}"

   # Loop over Containers
   local lcontainer
   for lcontainer in "${list_containers[@]}"
   do
       # Echo
       echo "Stop Container <${lcontainer}>"

       # Stop Container
       stop_container "${lcontainer}" "${luser}"
   done

   # Run podman-compose down
   generic_cmd "${luser}" "podman-compose" "down"
}

# Compose Up
compose_up() {
   # Compose Directory is Current Directory
   local lcomposedir=$(pwd)

   # Compose Arguments
   local lcomposeargs=${1-"-d"}

   # Podman Arguments
   local lpodmanargs=${2-""}

   # The User is passed as Optional Argument
   local luser=${3-""}
   if [[ -z "${luser}" ]]
   then
      luser=$(whoami)
   fi

   # Check if it's a valid Compose Directory
   # Abort on Error
   set -e
   compose_check_dir
   set +e

   # Always run compose_down first to make sure that the don't have some Systemd Service still running or restarting
   compose_down "${luser}"

   # Run podman-compose up
   generic_cmd "${luser}" "podman-compose" --podman-args="${lpodmanargs}" "up" "${lcomposeargs}"

   # Declare list_containers as a (global) array that we will pass to get_containers_from_compose_dir by reference
   declare -a list_containers

   # Get List of Containers Associated with Compose File by passing list_containers by reference
   get_containers_from_compose_dir list_containers "${lcomposedir}"

   # Loop over Containers
   local lcontainer
   for lcontainer in "${list_containers[@]}"
   do
       # Echo
       echo "Start Container <${lcontainer}>"

       # Start Container
       # No need - Container is already Started from podman-compose up -d
       #start_container "${lcontainer}" "${luser}"

       # Update Systemd Service File
       enable_autostart_container "${lcontainer}" "${luser}"
   done
}




# Enable Container Autostart
enable_autostart_container() {
   # The Container Name is passed as an Argument
   local lcontainer=${1}

   # The User is passed as Optional Argument
   local luser=${2-""}
   if [[ -z "${luser}" ]]
   then
      luser=$(whoami)
   fi

   # Get Systemd Configuration Folder
   local lsystemdfolder=$(get_systemdconfigdir "${luser}")

   # Get Systemd Service File Name
   local lservicefile=$(get_systemd_file_from_container "${lcontainer}")

   # Define Systemd Service File Path
   local lservicepath="${lsystemdfolder}/${lservicefile}"

   #if [[ -f "${lservicepath}" ]]
   #then
   #    # Update Service File if Required
   #    generic_cmd "${luser}" "podman" generate systemd --name ${lcontainer} --new > ${lsystemdfolder}/${lservicefile}
   #
   #    # Reload Systemd Configuration
   #    sleep 0.5
   #    systemd_reload "${luser}" "${lservicefile}"
   #    sleep 0.5
   #else
   #    # Generate New Service File
   #    generic_cmd "${luser}" "podman" generate systemd --name ${lcontainer} --new > ${lsystemdfolder}/${lservicefile}
   #
   #    # Enable & Restart Service
   #    sleep 0.5
   #    systemd_reload "${luser}" "${lservicefile}"
   #    sleep 0.5
   #    systemd_enable "${luser}" "${lservicefile}"
   #    systemd_restart "${luser}" "${lservicefile}"
   #fi

   # Delete file if exists already
   # Could prevent Systemd from printing Warning Messages such as:
   # >> The unit file, source configuration file or drop-ins of container-docker-local-mirror-registry.service changed on disk. Run 'systemctl --user daemon-reload' to reload units.
   if [[ -f "${lservicepath}" ]]
   then
       rm -f "${lservicepath}"
       sleep 0.5
       systemd_reload "${luser}" "${lservicefile}"
       sleep 0.5
   fi

   # Generate Service File
   generic_cmd "${luser}" "podman" generate systemd --name "${lcontainer}" --new > "${lservicepath}"

   # Enable & Restart Service
   sleep 0.5
   systemd_reload "${luser}" "${lservicefile}"
   sleep 0.5
   systemd_enable "${luser}" "${lservicefile}"
   systemd_restart "${luser}" "${lservicefile}"
}

# Disable Container Autostart
disable_autostart_container() {
   # The Container Name is passed as an Argument
   local lcontainer=${1}

   # The User is passed as Optional Argument
   local luser=${2-""}
   if [[ -z "${luser}" ]]
   then
      luser=$(whoami)
   fi

   # Get Systemd Configuration Folder
   local lsystemdfolder=$(get_systemdconfigdir "${luser}")

   # Get Systemd Service File Name
   local lservicefile=$(get_systemd_file_from_container "${lcontainer}")

   # Define Service Path
   local lservicepath="${lsystemdfolder}/${lservicefile}"

   if [[ -f "${lservicepath}" ]]
   then
      # Disable & Stop Service
      systemd_disable "${luser}" "${lservicefile}"
      systemd_stop "${luser}" "${lservicefile}"
      sleep 0.5
      systemd_reload "${luser}" "${lservicefile}"
      sleep 0.5

      # Remove Service File
      rm -f "${lservicepath}"

      # Reload Systemd again
      sleep 0.5
      systemd_reload "${luser}" "${lservicefile}"
      sleep 0.5
   fi
}

# List Containers
list_containers() {
   # The User is passed as Optional Argument
   local luser=${1-""}
   if [[ -z "${luser}" ]]
   then
      luser=$(whoami)
   fi

   # Get Systemd Configuration Folder
   local lsystemdfolder=$(get_systemdconfigdir "${luser}")

   # List using podman Command
   echo "================================================================="
   echo "================ Containers Currently Running ==================="
   echo "================================================================="
   generic_cmd "${luser}" "podman" "ps"

   # List Systemd Services
   echo "================================================================="
   echo "=============== Containers Systemd Configuration ================"
   echo "================================================================="

   # List Systemd Services
   mapfile -t list < <( ls -1 ${lsystemdfolder}/container-* )

   # Stop These Services which might be deprecated anyways
   #echo "Name|"
   local lservicepath=""
   for lservicepath in "${list[@]}"
   do
      # Need only the basename
      local lservicefile=$(basename "${lservicepath}")

      # Extract Container Name from Service File
      local lcontainer=$(get_container_from_systemd_file "${lservicefile}")

      local lisenabled=$(systemd_cmd "${luser}" "is-enabled" "${lservicefile}")
      local lisactive=$(systemd_cmd "${luser}" "is-active" "${lservicefile}")

      # Disable Autostart Container Service
      echo "Container <${lcontainer}> Configured in <${lservicepath}>: Enabled: ${lisenabled} / Active: ${lisactive}"
   done
}

# Status Container
status_container() {
    # The Container Name is passed as an Argument
    local lcontainer=${1}

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "${luser}" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    local lservicefile=$(get_systemd_file_from_container "${lcontainer}")

    # Get Container Status
    systemd_status "${luser}" "${lservicefile}"
}

# Journal Container
journal_container() {
    # The Container Name is passed as an Argument
    local lcontainer=${1}

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "${luser}" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    local lservicefile=$(get_systemd_file_from_container "${lcontainer}")

    # Show Journal
    journald_cmd "${luser}" "-xeu" "${lservicefile}" --no-pager
}

# Logs Container
logs_container() {
    # The Container Name is passed as an Argument
    local lcontainer=${1}

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "${luser}" ]]
    then
       luser=$(whoami)
    fi

    # Just show the Journal
    journal_container "${lcontainer}" "${luser}"
}

# Stop Container
stop_container() {
    # The Container Name is passed as an Argument
    local lcontainer=${1}

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "${luser}" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    local lservicefile=$(get_systemd_file_from_container "${lcontainer}")

    # Debug
    echo "Container: ${lcontainer}"
    echo "Systemd Service File: ${lservicefile}"

    if [[ ! -z "${lservicefile}" ]]
    then
       # Stop Systemd Service First of All
       systemd_stop "${luser}" "${lservicefile}"
    else
       # Stop using podman command
       # generic_cmd "${luser}" "podman" "stop" "${lcontainer}"
       local ldummy=1
    fi

    # Check if podman container exists
    local lexist=$(exists_container "${lcontainer}")
    if [[ $? -eq 0 ]]
    then
       # If exist code is 0, then the container exists
       generic_cmd "${luser}" "podman" "stop" "${lcontainer}"
    fi
}

# (Re)start Container
restart_container() {
    # The Container Name is passed as an Argument
    local lcontainer=${1}

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "${luser}" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    local lservicefile=$(get_systemd_file_from_container "${lcontainer}")

    # Debug
    echo "Container: ${lcontainer}"
    echo "Systemd Service File: ${lservicefile}"

    # Decide what to do, depending if Systemd Service exists or not
    if [[ ! -z "${lservicefile}" ]]
    then
       # Restart Systemd Service First of All
       systemd_restart "${luser}" "${lservicefile}"
    else
       # Restart using podman command
       generic_cmd "${luser}" "podman" "restart" "${lcontainer}"
    fi
}

# Start Container
start_container() {
    # The Container Name is passed as an Argument
    local lcontainer=${1}

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "${luser}" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    local lservicefile=$(get_systemd_file_from_container "${lcontainer}")

    # Debug
    echo "Container: ${lcontainer}"
    echo "Systemd Service File: ${lservicefile}"

    # Decide what to do, depending if Systemd Service exists or not
    if [[ ! -z "${lservicefile}" ]]
    then
       # Stop Systemd Service First of All
       systemd_stop "${luser}" "${lservicefile}"
    else
       # Stop using podman command
       generic_cmd "${luser}" "podman" "restart" "${lcontainer}"
    fi
}

# Remove Container
remove_container() {
    # The Container Name is passed as an Argument
    local lcontainer=${1}

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "${luser}" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    local lservicefile=$(get_systemd_file_from_container "${lcontainer}")

    # Debug
    echo "Container: ${lcontainer}"
    echo "Systemd Service File: ${lservicefile}"

    # Disable Container Autostart Service
    disable_autostart_container "${luser}" "${lcontainer}"

    # Stop Container
    stop_container "${lcontainer}" "${luser}"
}

# Check if Container Exists
exists_container() {
   # The Container Name is passed as an Argument
   local lquerycontainer=${1}

   # Get List of Running/Stopped Containers
   mapfile -t list < <( podman ps --all --format="{{.Names}}" )

   # Default to false
   local lfound=0

   # Loop over existing Containers
   local lcontainer=""
   for lcontainer in "${list[@]}"
   do
      if [[ "${lcontainer}" == "${lquerycontainer}" ]]
      then
         lfound=1
      fi
   done

   # Return Value
   #echo ${lfound}

   # Check the status of the Variable
   if [[ ${lfound} -eq 1 ]]
   then
      echo "Container <${lquerycontainer}> exists"
      exit 0
   else
      echo "Container <${lquerycontainer}> does NOT exist"
      exit 1
   fi

   # Alternative
   local lexist=$(podman )
   echo $?

}
