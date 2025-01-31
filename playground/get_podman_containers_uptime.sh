#!/bin/bash

# List Containers
mapfile -t list < <( podman ps --all --format="{{.Names}}" )

formatted=""

# Get current epoch time
now=$(date +%s)


for container in "${list[@]}"
do
    # Get uptime
#    duration_raw=$(podman stats --no-stream --no-reset --format="{{json .Duration}}" ${container})
#    duration_raw=$(podman stats --no-stream --no-reset --format="{{json .UpTime}}" ${container})
#
#    # Transform into seconds
#    duration_s=$((duration_raw/100000))

    # Get past epoch Time in which the container was started (constant value)
    startedat=$(podman ps --all --format="{{.StartedAt}}" --filter name=${container})

    # Get container running duration
    duration_s=$((now-startedat))

    # Transformer into hours
#    duration_h=$((duration_s/3600))
    duration_h=$(echo "scale=0; ${duration_s}/3600" | bc)

    # Format it
    #formatted="${formatted}${container} \t ${duration_s} s \t ${duration_h} h \n"
    formatted="${formatted}${container}|${duration_s} s|${duration_h} h \n"
done

#echo ${formatted} | column -t -s$'\t'
echo -e ${formatted} | column -t -s "|"
