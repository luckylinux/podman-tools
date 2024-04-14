#!/bin/bash

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

   # Return result
   echo $systemdconfigdir
}


# Execute Systemd Command
generic_cmd() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local command=$2
   local action=$3
   local service=$4

   executingUser=$(whoami)

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Run Command System-Wide
      $command $action $service
   else
      if [[ "$executingUser" == "root" ]]
      then
          # Run with runuser and with --user

          # Run Command as root user and target a different non-root User
          runuser -l $user -c "$command $action $service"
      elif [[ "$user" == "$executingUser" ]]
      then
          # Run without runuser and with --user

          # Run Systemd Command directly with --user Option (target user is the same as the user that is executing the script / function)
          $command --user $action $service
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
