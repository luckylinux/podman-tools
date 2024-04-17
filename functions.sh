#!/bin/bash

# Check if Array Contains Element
array_contains() {
    local larr=$1
    local lsearch=$2

    # Initialize Return Status
    lstatus=0

    # Loop over elements
    for item in "${larr[@]}"
    do
        if [[ "${item}" == "${lsearch}" ]]
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
    local lfilepath=$1
    local nargin=$#
    local nparameters=$(($(($nargin-1)) / 2))
    local ARGV=("$@")

    #Debug
    #echo "Passed $nargin arguments and $nparameters parameter"

    for ((p=1;p<=$nparameters;p++))
    do
        local iname=$((2*p-1))
        local ivalue=$(($iname+1))
        local name=${ARGV[$iname]}
        local value=${ARGV[$ivalue]}

        # Debug
        #echo "Replace {{$name}} -> ${value} in $lfilepath"

        # Execute Replacement
        sed -Ei "s|\{\{$name\}\}|$value|g" "$lfilepath"
    done
}

# Schedule Mode is NOT Supported
schedule_mode_not_supported() {
   local schedulemode=$1
   echo "Scheduling Mode <$schedulemode> is NOT supported. Possible choices are <cron> or <systemd>. Aborting !"
   exit 2
}

# Get Homedir
get_homedir() {
   local user=$1

   # Get homedir
   local homedir=$(getent passwd "$user" | cut -d: -f6)

   # Return result
   echo $homedir
}

# Get Systemdconfig
get_systemdconfigdir() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1

   if [[ "$user" == "root" ]]
   then
       local systemdconfigdir="/etc/systemd/system"
   else
       local userhomedir=$(get_homedir "$user")
       local systemdconfigdir="$userhomedir/.config/systemd/user"
   fi

   # Make sure to create it if not existing already
   if [[ ! -d "${systemdconfigdir}" ]]
   then
       mkdir -p "${systemdconfigdir}"
   fi

   # Return result
   echo $systemdconfigdir
}


# Execute Systemd Command
generic_cmd() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local command=$2
   local arguments="${@:3}"

   executingUser=$(whoami)

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Run Command System-Wide
      $command $action $arguments
   else
      if [[ "$executingUser" == "root" ]]
      then
          # Run with runuser and with --user

          # Run Command as root user and target a different non-root User
          runuser -l $user -c $command $arguments
      elif [[ "$user" == "$executingUser" ]]
      then
          # Run without runuser and with --user

          # Run Systemd Command directly with --user Option (target user is the same as the user that is executing the script / function)
          $command $arguments
      fi
   fi
}

# Execute Systemd Command
systemd_cmd() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local action=$2
   local service=$3

   executingUser=$(whoami)

   # Debug
   #echo "Execute systemd command targeting user <$user> with action <$action> for service <$service>"

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Run Command System-Wide
      systemctl $action $service
   else
      if [[ "$executingUser" == "root" ]]
      then
          # Run with runuser and with --user

          # Run Command as root user and target a different non-root User
          runuser -l "$user" -c "systemctl --user $action $service"
      elif [[ "$user" == "$executingUser" ]]
      then
          # Run without runuser and with --user

          # Run Systemd Command directly with --user Option (target user is the same as the user that is executing the script / function)
          systemctl --user $action $service
      fi
   fi
}


# Execute Systemd Command
journald_cmd() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local action=$2
   local service=$3

   executingUser=$(whoami)

   # Debug
   #echo "Execute journald command targeting user <$user> with action <$action> for service <$service>"

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Run Command System-Wide
      journalctl "$action" "$service"
   else
      if [[ "$executingUser" == "root" ]]
      then
          # Run with runuser and with --user

          # Run Command as root user and target a different non-root User
          runuser -l $user -c "journalctl --user \"$action\" \"$service\""
      elif [[ "$user" == "$executingUser" ]]
      then
          # Run without runuser and with --user

          # Run Systemd Command directly with --user Option (target user is the same as the user that is executing the script / function)
          journalctl --user "$action" "$service"
      fi
   fi
}


# Enable service(s)
systemd_enable() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   # Run Command using Wrapper
   systemd_cmd "$user" "enable" "$service"
}

# Disable service(s)
systemd_disable() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   # Run Command using Wrapper
   systemd_cmd "$user" "disable" "$service"
}

# Status of service(s)
systemd_status() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   # Run Command using Wrapper
   systemd_cmd "$user" "status" "$service"
}

systemd_restart() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   # Run Command using Wrapper
   systemd_cmd "$user" "restart" "$service"
}

systemd_stop() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   # Run Command using Wrapper
   systemd_cmd "$user" "stop" "$service"
}

systemd_start() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   # Run Command using Wrapper
   systemd_cmd "$user" "start" "$service"
}


systemd_reload() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1

   # Run Command using Wrapper
   systemd_cmd "$user" "daemon-reload"
}

systemd_reexec() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1

   # Run Command using Wrapper
   systemd_cmd "$user" "daemon-reexec"
}

journald_log() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   #  Run Command using Wrapper
   journald_cmd "$user" "-xeu" "$service"
}

# Shortcut to Systemd daemon-reload + enable + restart service
systemd_reload_enable() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   # Reload Systemd Service Files
   systemd_reload "$user" "$service"

   # Enable the Service to start automatically at each boot
   systemd_enable "$user" "$service"

   # Start the Service
   systemd_restart "$user" "$service"

   # Verify the Status is OK
   systemd_status "$user" "$service"

   # Check the logs from time to time and in case of issues
   journald_log "$user" "$service"
}



# List subuid / subgid
list_subuid_subgid() {
     local SUBUID=/etc/subuid
     local SUBGID=/etc/subgid

     for i in $SUBUID $SUBGID; do [[ -f "$i" ]] || { echo "ERROR: $i does not exist, but is required."; exit 1; }; done
     [[ -n "$1" ]] && USERS=$1 || USERS=$(awk -F : '{x=x " " $1} END{print x}' $SUBUID)
     for i in $USERS; do
        awk -F : "\$1 ~ /$i/ {printf(\"%-16s sub-UIDs: %6d..%6d (%6d)\", \$1 \",\", \$2, \$2+\$3, \$3)}" $SUBUID
        awk -F : "\$1 ~ /$i/ {printf(\", sub-GIDs: %6d..%6d (%6d)\", \$2, \$2+\$3, \$3)}" $SUBGID
        echo ""
     done
}

# Get Homedir
get_homedir() {
   local user=$1

   # Get homedir
   local homedir=$(getent passwd "$user" | cut -d: -f6)

   # Return result
   echo $homedir
}

# Make Mutable if Exist
make_mutable_if_exist() {
    local target=$1

    if [ -d "${target}" ] || [ -f "${target}" ]
    then
       # Remove the Immutable Flag
       chattr -i "${target}"
    fi
}

# Make Immutable if Exist
make_immutable_if_exist() {
    local target=$1

    if [ -d "${target}" ] || [ -f "${target}" ]
    then
       # Add the Immutable Flag
       chattr +i "${target}"
    fi
}

# Move if Exist
move_if_exist() {
    local origin=$1
    local destination=$2

    if [ -d "${origin}" ] || [ -f "${origin}" ]
    then
       # Move to Destination
       mv "${origin}" "${destination}"
    fi
}

# Remove empty Folder if Exist
rmdir_if_exist() {
    local target=$1

    if [ -d "${target}" ]
    then
       # Attempt to remove Empty Folder
       rmdir "${target}"

       # Check Return Code
       if [[ "$?" -ne 0 ]]
       then
          echo "FAILED to remove Folder <${target}>. Error code of `rmdir` was $?. Possible NON-EMPTY Directory ?"
       fi
    fi
}

# Remove leading and/or trailing Slashes ("/")
remove_leading_trailing_slashes() {
    # Init Variable
    local lsanitized=$1

    # Remove leading and trailing Slashes
    lsanitized=${lsanitized%/};
    lsanitized=${lsanitized#/}

    # Echo & Return
    echo $lsanitized
}

# Get Containers Associated with Compose File
get_containers_from_compose_dir() {
   # The return Array is passed by nameref
   declare -n lreturnarray="$1"  # Reference to output array

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
   for item in "${llist[@]}"
   do
       #echo $item

       # Perfom Cleaning of the Item String
       cleanitem=$(echo $item | sed -E "s|^\s*?#?\s*?container_name:\s*?([a-zA-Z0-9_-]+)\s*?$|\1|g")

       #echo "Clean Item: <$cleanitem>"

       # Check if it's already in Array
       chk=$(array_contains locallist "${cleanitem}")

       lreturnarray+=("${cleanitem}")

       # If Status is 0 then add to return array
       #if [[ $chk -eq 0 ]]
       #then
       #    lreturnarray+=("${cleanitem}")
       #fi
   done
}

# Get Systemd Service File from Container Name
get_systemd_file_from_container() {
    # The Container Name is passed as an Argument
    local lcontainer=$1

    # Define Service File
    servicefile="container-${lcontainer}.service"

    # Return
    echo $servicefile
}

# Get Container Name from Systemd Service File
get_container_from_systemd_file() {
    # The Service Name is passed as an Argument
    local lservice=$1

    # Strip "container-" from string
    container="$lservice"
    container=${container/"container-"/""}
    container=${container/".service"/""}

    # Return
    echo $container
}

# Get Systemd File
#get_systemd_file_from_container() {
#    # The Container Name is passed as an Argument
#    local lname=$1
#
#    # Extract Systemd File from Container
#    servicefile=$(podman inspect $lname | jq -r '.[0].Config.Labels."PODMAN_SYSTEMD_UNIT"')
#
#    # Return
#    echo $servicefile
#}

# Get Container Compose File
get_compose_dir_from_container() {
    # The Container Name is passed as an Argument
    local lcontainer=$1

    # Extract compodir from Container
    composedir=$(podman inspect $lcontainer | jq -r '.[0].Config.Labels."com.docker.compose.project.working_dir"')

    # Return
    echo $composedir
}

# Update Compose
compose_update() {
   # Compose Directory is Current Directory
   local lcomposedir=$(pwd)

   # The User is passed as Optional Argument
   local luser=${1-""}
   if [[ -z "$luser" ]]
   then
      luser=$(whoami)
   fi

   # Run compose_down
   compose_down "${luser}"

   # Run compose_up
   compose_up "${luser}"
}

# Compose Down
compose_down() {
   # Compose Directory is Current Directory
   local lcomposedir=$(pwd)

   # The User is passed as Optional Argument
   local luser=${1-""}
   if [[ -z "$luser" ]]
   then
      luser=$(whoami)
   fi

   # Declare list_containers as a (global) array that we will pass to get_containers_from_compose_dir by reference
   declare -a list_containers

   # Get List of Containers Associated with Compose File by passing list_containers by reference
   get_containers_from_compose_dir list_containers "${lcomposedir}"

   # Loop over Containers
   for container in "${list_containers[@]}"
   do
       # Echo
       echo "Updating Container <${container}>"

       # Stop Container
       stop_container "${container}" "${luser}"
   done

   # Run podman-compose down
   generic_cmd "${luser}" "podman-compose" "down"
}

# Compose Up
compose_up() {
   # Compose Directory is Current Directory
   local lcomposedir=$(pwd)

   # The User is passed as Optional Argument
   local luser=${1-""}
   if [[ -z "$luser" ]]
   then
      luser=$(whoami)
   fi

   # Always run compose_down first to make sure that the don't have some Systemd Service still running or restarting
   compose_down "${luser}"

   # Run podman-compose up
   generic_cmd "${luser}" "podman-compose" "up -d"

   # Declare list_containers as a (global) array that we will pass to get_containers_from_compose_dir by reference
   declare -a list_containers

   # Get List of Containers Associated with Compose File by passing list_containers by reference
   get_containers_from_compose_dir list_containers "${lcomposedir}"

   # Loop over Containers
   for container in "${list_containers[@]}"
   do
       # Echo
       echo "Updating Container <${container}>"

       # Start Container
       # No need - Container is already Started from podman-compose up -d
       #start_container "${container}" "${luser}"

       # Update Systemd Service File
       enable_autostart_container "${container}" "${luser}"
   done
}




# Enable Container Autostart
enable_autostart_container() {
   # The Container Name is passed as an Argument
   local lcontainer=$1

   # The User is passed as Optional Argument
   local luser=${2-""}
   if [[ -z "$luser" ]]
   then
      luser=$(whoami)
   fi

   # Get Systemd Configuration Folder
   systemdfolder=$(get_systemdconfigdir "${luser}")

   # Define Service File
   servicefile="container-${container}.service"

   #if [[ -f "${servicepath}" ]]
   #then
   #    # Update Service File if Required
   #    generic_cmd "${luser}" "podman" generate systemd --name $container --new > ${systemdfolder}/$servicefile
   #
   #    # Reload Systemd Configuration
   #    systemd_reload "${user}"
   #else
   #    # Generate New Service File
   #    generic_cmd "${luser}" "podman" generate systemd --name $container --new > ${systemdfolder}/$servicefile
   #
   #    # Enable & Restart Service
   #    systemd_reload "${user}"
   #    systemd_enable "${user}" "${servicename}"
   #    systemd_restart "${user}" "${servicename}"
   #fi


   # Generate Service File
   generic_cmd "${luser}" "podman" generate systemd --name "${container}" --new > "${systemdfolder}/${servicefile}"

   # Enable & Restart Service
   systemd_reload "${luser}"
   systemd_enable "${luser}" "${servicefile}"
   systemd_restart "${luser}" "${servicefile}"
}

# Disable Container Autostart
disable_autostart_container() {
   # The Container Name is passed as an Argument
   local lcontainer=$1

   # The User is passed as Optional Argument
   local luser=${2-""}
   if [[ -z "$luser" ]]
   then
      luser=$(whoami)
   fi

   # Get Systemd Configuration Folder
   systemdfolder=$(get_systemdconfigdir $luser)

   # Define Service File
   servicefile="container-${container}.service"

   # Define Service Path
   servicepath="${systemdfolder}/${servicefile}"

   if [[ -f "$servicepath" ]]
   then
      # Disable & Stop Service
      systemd_disable "${luser}" "${servicefile}"
      systemd_stop "${luser}" "${servicefile}"
      systemd_reload "${luser}"

      # Remove Service File
      rm -f "${systemdfolder}/${servicefile}"

      # Reload Systemd again
      systemd_reload "${luser}"
   fi
}

# List Containers
list_containers() {
   # The User is passed as Optional Argument
   local luser=${1-""}
   if [[ -z "$luser" ]]
   then
      luser=$(whoami)
   fi

   # Get Systemd Configuration Folder
   systemdfolder=$(get_systemdconfigdir $luser)

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
   mapfile -t list < <( ls -1 ${systemdfolder}/container-* )

   # Stop These Services which might be deprecated anyways
   #echo "Name|"
   for servicepath in "${list[@]}"
   do
      # Need only the basename
      servicefile=$(basename ${servicepath})

      # Extract Container Name from Service File
      container=$(get_container_from_systemd_file "${servicefile}")

      isenabled=$(systemd_cmd "${luser}" "is-enabled" "${servicefile}")
      isactive=$(systemd_cmd "${luser}" "is-active" "${servicefile}")

      # Disable Autostart Container Service
      echo "Container <${container}> Configured in <${servicepath}>: Enabled: ${isenabled} / Active: ${isactive}"
   done
}

# Stop Container
stop_container() {
    # The Container Name is passed as an Argument
    local lcontainer=$1

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "$luser" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    servicefile=$(get_systemd_file_from_container "$container")

    if [[ ! -z "$servicefile" ]]
    then
       # Stop Systemd Service First of All
       systemd_stop "${luser}" "${servicefile}"
    else
       # Stop using podman command
       generic_cmd "${luser}" "podman" "stop" "${lcontainer}"
    fi
}

# (Re)start Container
restart_container() {
    # The Container Name is passed as an Argument
    local lcontainer=$1

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "$luser" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    servicefile=$(get_systemd_file_from_container "${lcontainer}")

    if [[ ! -z "$servicefile" ]]
    then
       # Restart Systemd Service First of All
       systemd_restart "${luser}" "${servicefile}"
    else
       # Restart using podman command
       generic_cmd "${luser}" "podman" "restart" "${lcontainer}"
    fi
}

# Start Container
start_container() {
    # The Container Name is passed as an Argument
    local lcontainer=$1

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "$luser" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    servicefile=$(get_systemd_file_from_container "${lcontainer}")

    if [[ ! -z "$servicefile" ]]
    then
       # Stop Systemd Service First of All
       systemd_stop "${luser}" "${servicefile}"
    else
       # Stop using podman command
       generic_cmd "${luser}" "podman" "restart" "${lcontainer}"
    fi
}

# Remove Container
remove_container() {
    # The Container Name is passed as an Argument
    local lcontainer=$1

    # The User is passed as Optional Argument
    local luser=${2-""}
    if [[ -z "$luser" ]]
    then
       luser=$(whoami)
    fi

    # Get Systemd Service File Name
    servicefile=$(get_systemd_file_from_container "${lcontainer}")

    # Disable Container Autostart Service
    disable_autostart_container "${luser}" "${lcontainer}"

    # Stop Container
    stop_container "${lcontainer}" "${luser}"
}

# Check if Container Exists
exists_container() {
   # The Container Name is passed as an Argument
   local lquerycontainer=$1

   # Get List of Running/Stopped Containers
   mapfile -t list < <( podman ps --all --format="{{.Names}}" )

   # Default to false
   found=0

   # Loop over existing Containers
   for container in "${list[@]}"
   do
      if [[ "${container}" == "${lquerycontainer}" ]]
      then
         found=1
      fi
   done

   # Return Value
   #echo $found

   # Check the status of the Variable
   if [[ ${found} -eq 1 ]]
   then
      echo "Container <${lquerycontainer}> exists"
      exit 0
   else
      echo "Container <${lquerycontainer}> does NOT exist"
      exit 1
   fi
}

