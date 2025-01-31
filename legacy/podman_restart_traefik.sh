#!/bin/bash

# List Containers
mapfile -t list < <( podman ps --all --format="{{.Names}}" )

formatted=""

# Get current epoch time
now=$(date +%s)

# Get past epoch Time in which traefik was started (constant value)
traefik_startedat=$(podman ps --all --format="{{.StartedAt}}" --filter name=traefik)

# Get traefik running duration
traefik_duration_s=$((now-traefik_startedat))

# Define if traefik must be restarted
traefik_restart=0

for container in "${list[@]}"
do
    # Get past epoch Time in which the container was started (constant value)
    container_startedat=$(podman ps --all --format="{{.StartedAt}}" --filter name=${container})

    # Get container running duration
    container_duration_s=$((now-container_startedat))

    # Compare against traefik started time
    if [[ ${traefik_startedat} -lt ${container_startedat} ]]
    then
        echo "Container ${container} was started AFTER traefik Proxy Server. Restarting Traefik Necessary"
        traefik_restart=1
    fi

    # Transformer into hours
    #container_duration_h=$(echo "scale=0; ${container_duration_s}/3600" | bc)

    # Format it
    #formatted="${formatted}${container}|${container_duration_s} s|${container_duration_h} h \n"
done

#echo ${formatted} | column -t -s$'\t'
#echo -e ${formatted} | column -t -s "|"


if [[ ${traefik_restart} -gt 0 ]]
then
    # Restart traefik container
    echo "Restarting traefik container"
    systemd_restart "container-traefik.service"
fi
