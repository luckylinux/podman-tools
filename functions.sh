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



# Shortcut to Systemd daemon-reload + enable + restart service
systemd_reload_enable() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Reload Systemd Service Files
      systemctl daemon-reload

      # Enable the Service to start automatically at each boot
      systemctl enable "$service"

      # Start the Service
      systemctl restart "$service"

      # Verify the Status is OK
      systemctl status "$service"

      # Check the logs from time to time and in case of issues
      journalctl -xeu "$service"

   else
      # Run with runuser and with --user

      # Reload Systemd Service Files
      runuser -l $user -c "systemctl --user daemon-reload"

      # Enable the Service to start automatically at each boot
      runuser -l $user -c "systemctl --user enable $service"

      # Start the Service
      runuser -l $user -c "systemctl --user restart $service"

      # Verify the Status is OK
      runuser -l $user -c "systemctl --user status $service"

      # Check the logs from time to time and in case of issues
      runuser -l $user -c "journalctl --user -xeu $service"
   fi
}

# Execute Systemd Command
systemd_cmd() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local command=$2
   local service=$3

   executingUser=$(whoami)

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Run Command System-Wide
      systemctl $command $service
   else
      if [[ "$executingUser" == "root" ]]
      then
          # Run with runuser and with --user

          # Run Command as root user and target a different non-root User
          runuser -l $user -c "systemctl --user $command $service"
      elif [[ "$user" == "$executingUser" ]]
      then
          # Run without runuser and with --user

          # Run Systemd Command directly with --user Option (target user is the same as the user that is executing the script / function)
          systemctl --user $command $service
      fi
   fi
}

# Status of service(s)
systemd_status() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   # Run Command using Wrapper
   systemd_cmd "$user" status "$service"
}


systemd_restart() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   # Run Command using Wrapper
   systemd_cmd "$user" restart "$service"


   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Restart Service
      systemctl restart $service

   else
      # Run with runuser and with --user

      # Restart Service
      runuser -l $user -c "systemctl --user restart $service"
   fi
}

systemd_stop() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Stop Service
      systemctl restart $service

   else
      # Run with runuser and with --user

      # Stop Service
      runuser -l $user -c "systemctl --user restart $service"
   fi
}

systemd_start() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Start Service
      systemctl start $service

   else
      # Run with runuser and with --user

      # Start Service
      runuser -l $user -c "systemctl --user start $service"
   fi
}


systemd_reload() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Reload Systemd Service Files
      systemctl daemon-reload

   else
      # Run with runuser and with --user

      # Reload Systemd Service Files
      runuser -l $user -c "systemctl --user daemon-reload"
   fi
}

systemd_reexec() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2


   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Reexecute Systemd
      systemctl daemon-reexec

   else
      # Run with runuser and with --user

      # Reexecute Systemd
      runuser -l $user -c "systemctl --user daemon-reexec"
   fi
}

systemd_log() {
   # User is the TARGET user, NOT (necessarily) the user executing the script / function !
   local user=$1
   local service=$2

   if [[ "$user" == "root" ]]
   then
      # Run without runuser and without --user

      # Show Systemd Log
      journalctl --user -xeu $service

   else
      # Run with runuser and with --user

      # Show Systemd Log
      runuser -l $user -c "journalctl --user -xeu $service"
   fi
}
