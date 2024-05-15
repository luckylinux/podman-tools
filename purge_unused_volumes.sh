#!/bin/bash

# Get list of Volumes
mapfile -t volumes < <( podman volume ls --quiet )

# Declare array for unused Volumes
unusedvolumes=()

# Iterate over Volumes
for volume in "${volumes[@]}"
do
    # Echo
    #echo "Processing Volume ${volume}"

    # Check to see if Volume is used by any Container
    usedbyid=$(podman ps -a --filter volume="${volume}" --quiet)

    # If no Containers are associated then it's a dangling Volume
    if [[ -z "${usedbyid}" ]]
    then
       # Echo
       echo "Volume ${volume} appears unused"

       # Add to Array
       unusedvolumes+=("${volume}")
    else
       # Get Container Name from ID
       usedbyname=$(podman ps -a --filter id="${usedbyid}" --format="{{.Names}}" --quiet)

       # Echo
       echo "SKIPPING Volume ${volume} which is used by Container ${usedbyid} (${usedbyname})"
    fi
done

# Ask user to purge unused volumes
read -p "Do you want to Purge unused Volumes [yes/no]: " purgeunusedvolumes

# Exit
if [[ "${purgeunusedvolumes}" != "yes" ]]
then
    exit 0
fi

# List Volumes that would be deleted
echo "The following Volumes are unused and are going do be deleted:"
for volume in "${unusedvolumes[@]}"
do
   echo -e "\t${volume}"
done

# Ask user if really sure
read -p "Are you REALLY sure you want to proceed ? This action CANNOT be undone [yes/no]: " purgeunusedvolumesconfirmation

# Exit
if [[ "${purgeunusedvolumesconfirmation}" != "yes" ]]
then
    exit 0
fi

# Extra check to REALLY be sure
if [[ "${purgeunusedvolumesconfirmation}" == "yes" ]]
then
   # Purge unused Volumes
   echo "Purge unused Volumes as requested:"
   for volume in "${unusedvolumes[@]}"
   do
      # Echo
      echo -e "\tPurging Volume ${volume}"

      # Purge Volume
      podman volume rm "${volume}"
   done
fi
