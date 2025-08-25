#!/bin/bash

while true
do
   # Check if Traefik Container Exists first of all
   podman container exists "traefik"

   # Store exitcode (needed otherwise the exitcode of the function would be the exitcode of "echo" function)
   # 0 = exists
   traefik_exists=$?

   # This might  not be sufficient in case Traefik is already stopped
   if [ -d "$HOME/containers/compose/traefik" ] || [ -d "$HOME/compose/traefik" ]
   then
      # 0 = exists
      traefik_exists=0
   fi

   # List Containers
   mapfile -t list < <( podman ps --all --format="{{.Names}}" )

   #formatted=""

   # Get current epoch time
   now=$(date +%s)

   # Get past epoch Time in which traefik was started (constant value)
   traefik_startedat=$(podman ps --all --format="{{.StartedAt}}" --filter name=^traefik\$)

   # Get traefik running duration
   traefik_duration_s=$((now-traefik_startedat))

   # Define if traefik must be restarted
   traefik_restart=0

   for container in "${list[@]}"
   do
       if [[ "${container}" == "traefik" ]]
       then
           # Echo
           #echo "Skipping container <${container}>"
           skip=1
       else
           # Echo
           #echo "Processing container <${container}>"

           # Get past epoch Time in which the container was started (constant value)
           container_startedat=$(podman ps --all --format="{{.StartedAt}}" --filter name=^${container}\$)
           #started=${container_startedat}

           # Get container running duration
           container_duration_s=$((now-container_startedat))

           # Compare against traefik started time
           #echo "if [[ ${traefik_startedat} -lt ${container_startedat} ]]"
           if [[ ${traefik_startedat} -lt ${container_startedat} ]]
           then
              echo "Container ${container} was started AFTER traefik Proxy Server. Restarting Traefik Necessary"
              traefik_restart=1
           fi

           # Transformer into hours
           #container_duration_h=$(echo "scale=0; ${container_duration_s}/3600" | bc)

           # Format it
           #formatted="${formatted}${container}|${container_duration_s} s|${container_duration_h} h \n"
       fi
   done

   #echo ${formatted} | column -t -s$'\t'
   #echo -e ${formatted} | column -t -s "|"

   # If Traefik Container Exists
   if [[ ${traefik_exists} -eq 0 ]]
   then
       if [[ ${traefik_restart} -gt 0 ]]
       then
          # Restart traefik container
          echo "Restarting traefik container"
          systemctl --user restart container-traefik
       fi
   fi

   # Wait a bit
   sleep 15
done
