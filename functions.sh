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
