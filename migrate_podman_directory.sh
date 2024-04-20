#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Configuration
source ${toolpath}/config.sh

# Load Functions
source ${toolpath}/functions.sh

# Abort if Script is NOT being Executed as Root
if [ "${EUID}" -ne 0 ]
  then echo "Script MUST be run as root"
  exit
fi

# User Name
user=${1}
#user=${1-"podman"}

# Source Directory
sourcedir=${2}
#sourcedir=${2-"/home/podman"}

# Destination Directory
destinationdir=${3}
#destinationdir=${3-"/home/podman/containers"}

# Create Destination Directory if Not Existing Yet
mkdir -p ${destinationdir}
chattr -i ${destinationdir}/*
chown -R ${user}:${user} ${destinationdir}

# Storage.conf File Location
# MUST still be available after all things have been unmounted
configrealpath=${4}
#configrealpath=${4-"/zdata/PODMAN/CONFIG"} # Contains storage.conf

# Paths for use in config files
# It's better to avoid using --rbind paths such as /home/podman/containers/storage for graphRoot and similar.
# Less issues when accessing directly /zdata/PODMAN/*
# The mountpoints is still available though
# If SET, the UPPERCASE Dataset values will be used (STORAGE, IMAGES, VOLUMES, ...)
# If UNSET, the LOWERCASE Dataset values will be used (storage, images, volumes, ...)
pathsforuseinconfigfiles=${5-""}


# Make sure that all mountpoints are mounted prior to performing migration
zfs mount -a
mount -a


# Get homedir
homedir=$(get_homedir "${user}")

# Get Systemdconfigdir
systemdconfigdir=$(get_systemdconfigdir "${user}")

# Save current path
currentpath=$(pwd)



# Stop all Running Containers based only on Podman Running Status
mapfile -t runninglist < <( podman ps --all --format="{{.Names}}" )

for container in "${runninglist[@]}"
do
   echo "Disable & Stop Systemd Autostart Service for <${container}>"

   # Define where service file would be located
   #service="container-${container}"
   service=$(podman inspect ${container} | jq -r '.[0].Config.Labels."PODMAN_SYSTEMD_UNIT"')

   # Disable Service Temporarily
   systemd_disable "${user}" "${service}"

   # Stop Service
   systemd_stop "${user}" "${service}"
done

# Stop all Containers based on Podman Compose file Structure
if [[ -d "${sourcedir}/compose/" ]]
then
   for filepath in ${sourcedir}/compose/*
   do
      # Container is only the basename
      container=$(basename ${filepath})

      echo "Run podman-compose down for <${container}>"

      # Determine Compose Directory
      composedir=$(podman inspect ${container} | jq -r '.[0].Config.Labels."com.docker.compose.project.working_dir"')

      # Change Directory
      cd ${sourcedir}/compose/${container} || exit

      # Bring Podman Container down
      generic_cmd "${user}" "podman-compose" "down"

      # Another Attempt
      cd ${composedir} || exit
      generic_cmd "${user}" "podman-compose" "down"
   done
fi

# Stop simply using "podman" command if there are Containers which do NOT have a Systemd Service (yet) and were NOT generated using podman-compose
mapfile -t remaininglist < <( podman ps --all --format="{{.Names}}" )

for container in "${remaininglist[@]}"
do
   echo "Stop Podman Container <${container}> using `podman` Command"

   # Stop Container
   generic_cmd "${user}" "podman" "stop" "${service}"
done



# Determine which Paths to use in storage.conf files
if [[ -z "${pathsforuseinconfigfiles}" ]]
then
   storagepath="${destinationdir}/storage"
   imagespath="${destinationdir}/images"
   volumespath="${destinationdir}/volumes"
else
   storagepath="${pathsforuseinconfigfiles}/STORAGE"
   imagespath="${pathsforuseinconfigfiles}/IMAGES"
   volumespath="${pathsforuseinconfigfiles}/VOLUMES"
fi

# Make changes to storage.conf
sed -Ei "s|^#? ?graphroot = \".*\"|graphroot = \"${storagepath}\"|g" "${configrealpath}/storage.conf"
sed -Ei "s|^#? ?rootless_storage_path = \".*\"|rootless_storage_path = \"${storagepath}\"|g" "${configrealpath}/storage.conf"

# Using Imagestore gives problems so make sure to Disable it in the Process !
sed -Ei "s|^#? ?imagestore = \".*\"|#imagestore = \"${imagespath}\"|g" "${configrealpath}/storage.conf"

# Make changes to registries.conf
# ...

# Make changes to containers.conf
# Also fix wrong "volumepath" syntax to the correct "volume_path"
sed -Ei "s|^#? ?volumepath = \".*\"|volume_path = \"${volumespath}\"|g" "${configrealpath}/storage.conf"
sed -Ei "s|^#? ?volume_path = \".*\"|volume_path = \"${volumespath}\"|g" "${configrealpath}/storage.conf"

# Unmount all mountpoints
zfs umount -a
umount -a

# Loop over Datasets
# Create Datasets
for dataset in "${datasets[@]}"
do
        # Convert dataset name to lowercase mountpoint
        lname=${dataset,,}

        # Source Path
        sourcepath="${sourcedir}/${lname}"

        # Destination Path
        destinationpath="${destinationdir}/${lname}"

        # If dataset does not exist yet, create it
        if [[ ! -d "${sourcepath}" ]]
        then
           mkdir -p "${sourcepath}"
           chown -R ${user}:${user} ${sourcedir}/${lname}
        fi

        # Make it editable
        chattr -i ${sourcepath}

        # If folder has already been created on destination, attempt to remove it (if empty only !)
        if [[ -d "${destinationpath}" ]]
        then
            # Echo
            echo "Destination folder <${destinationpath}> already exists. Attempting to remove (only if EMPTY !)"

            # Make it editable
            chattr -i ${destinationpath}

            # Attempt to Remove it
            rmdir "${destinationpath}"

            # Check Return Code
            if [[ "$?" -ne 0 ]]
            then
                echo "FAILED to remove Destination folder <${destinationpath}>. Error code of `rmdir` was $?. Possible NON-EMPTY Directory !"
            fi
        fi

        if [[ -d "${sourcepath}" ]]
        then
           # Move mountpoint if it still exists on the source
           mv ${sourcepath} ${destinationpath}
        else
           # Create a new Directory from scratch
           mkdir -p ${destinationpath}
        fi

        # Give User Ownership
        chown -R ${user}:${user} ${destinationpath}

        # Require that a partition is mounted there again
        chattr +i "${destinationpath}"

        # Make changes to /etc/fstab
        sed -Ei "s|${sourcepath}|${destinationpath}|g" "/etc/fstab"
done

# Special Cases: "backup" and "restoretmp" are NOT using Local Storage
# Make it modifiable
make_mutable_if_exist "${sourcedir}/backup"
make_mutable_if_exist "${sourcedir}/restoretmp"
make_mutable_if_exist "${destinationdir}/backup"
make_mutable_if_exist "${destinationdir}/restortmp"

# Remove Directories in Source Folder if they still exist
rmdir_if_exist "${sourcedir}/backup"
rmdir_if_exist "${sourcedir}/restoretmp"

# Create Destination Directory if not exist already
mkdir -p "${destinationdir}/backup"
mkdir -p "${destinationdir}/restoretmp"

# Give User Ownership
chown -R ${user}:${user} "${destinationdir}/backup"
chown -R ${user}:${user} "${destinationdir}/restoretmp"

# Make them Immutable again
make_immutable_if_exist "${destinationdir}/backup"
make_immutable_if_exist "${destinationdir}/restoretmp"

# Make changes to /etc/fstab
sed -Ei "s|${sourcedir}/backup|${destinationdir}/backup|g" "/etc/fstab"
sed -Ei "s|${sourcedir}/restoretmp|${destinationdir}/restoretmp|g" "/etc/fstab"

# Load new FSTAB Configuration
systemctl daemon-reload

# Load new FSTAB Configuration as User
systemd_reload "${user}"

# Remount all mountpoints
zfs mount -a
mount -a

# Now All compose.yml files need to be updated
mapfile -t composefilelist < <( find ${destinationdir}/compose -type f \( -name "compose.yml" -o -name "docker-compose.yml" -o -name "container-compose.yml" \) )

# Also add backup & restoretmp to the list
mapfile+=("backup")
mapfile+=("restoretmp")

# Generate Timestamp
timestamp=$(date +"%Y%m%d-%H%M%S")

# For each Compose File
for composefile in "${composefilelist[@]}"
do
   # Create backup before replacement
   echo "Create Backup of ${composefile} in ${composefile}.backup.${timestamp}"
   cp "${composefile}" "${composefile}.backup.${timestamp}"

   # For each Dataset
   for dataset in "${datasets[@]}"
   do
        # Convert dataset name to lowercase mountpoint
        lname=${dataset,,}

        # Absolute Path
        originabsolutepath="${sourcedir}/${lname}"
        destinationabsolutepath="${destinationdir}/${lname}"

        # With trailing /
        originabsolutepathwithtrailingslash="${originabsolutepath}/"
        destinationabsolutepathwithtrailingslash="${destinationabsolutepath}/"

        # Echo
        #echo "Absolute Paths: ${originabsolutepath} -> ${destinationabsolutepath}"
        #echo "Absolute Paths with Trailing Slash: ${originabsolutepathwithtrailingslash} -> ${destinationabsolutepathwithtrailingslash}"
        #echo "Homedir: ${homedir}"

        # Relative Path compared to Homedir
        originrelativepath=$(realpath --canonicalize-missing ${originabsolutepathwithtrailingslash/${homedir}/""})
        destinationrelativepath=$(realpath --canonicalize-missing ${destinationabsolutepathwithtrailingslash/${homedir}/""})

        # Strip the additional slash
        originrelativepath=$(remove_leading_trailing_slashes "${originrelativepath}")
        destinationrelativepath=$(remove_leading_trailing_slashes "${destinationrelativepath}")

        #echo "Relative Paths: ${originrelativepath} -> ${destinationrelativepath}"

        # Echo
        echo "Replace ~/${originrelativepath}/(.*) -> ~/${destinationrelativepath}/(.*)"
        echo "Replace ${originabsolutepath}/(.*) -> ${destinationabsolutepath}/(.*)"

        # We must both support:
        # - ~/<dataset>:SOMETHING
        # - /home/${user}:SOMETHING

        # Temporary Fix: Fix wrong Indentation due to previous Error in sed expression
        #sed -Ei "s|^(\s*)\-\s*?~/${originrelativepath}/(.*)|      - ~/${originrelativepath}/\2|g" "${composefile}"
        #sed -Ei "s|^(\s*)\-\s*?${originabsolutepath}/(.*)|      - ${originabsolutepath}/\2|g" "${composefile}"


        ### Replace Volumes Section

        # Simple Strings
        sed -Ei "s|^(\s*)\-\s*?~/${originrelativepath}/(.*)$|\1- ~/${destinationrelativepath}/\2|g" "${composefile}"
        sed -Ei "s|^(\s*)\-\s*?${originabsolutepath}/(.*)$|\1- ${destinationabsolutepath}/\2|g" "${composefile}"

        # Within Single Quotes
        sed -Ei "s|^(\s*)\-\s*?'~/${originrelativepath}/(.*)'(.*?)$|\1- '~/${destinationrelativepath}/\2'\3|g" "${composefile}"
        sed -Ei "s|^(\s*)\-\s*?'${originabsolutepath}/(.*)'(.*?)$|\1- '${destinationabsolutepath}/\2'\3|g" "${composefile}"

        # Within Double Quotes
        sed -Ei "s|^(\s*)\-\s*?\"~/${originrelativepath}/(.*)\"(.*?)$|\1- \"~/${destinationrelativepath}/\2\"\3|g" "${composefile}"
        sed -Ei "s|^(\s*)\-\s*?\"${originabsolutepath}/(.*)\"(.*?)$|\1- \"${destinationabsolutepath}/\2\"\3|g" "${composefile}"

        #### Replace Secrets Section

        # Simple Strings
        sed -Ei "s|^(\s*)file:\s*?~/${originrelativepath}/(.*)$|\1file: ~/${destinationrelativepath}/\2|g" "${composefile}"
        sed -Ei "s|^(\s*)file:\s*?${originabsolutepath}/(.*)$|\1file: ${destinationabsolutepath}/\2|g" "${composefile}"

        # Within Single Quotes
        sed -Ei "s|^(\s*)file:\s*?'~/${originrelativepath}/(.*)'(.*?)$|\1file: '~/${destinationrelativepath}/\2'\3|g" "${composefile}"
        sed -Ei "s|^(\s*)file:\s*?'${originabsolutepath}/(.*)'(.*?)$|\1file: '${destinationabsolutepath}/\2'\3|g" "${composefile}"

        # Within Double Quotes
        sed -Ei "s|^(\s*)file:\s*?\"~/${originrelativepath}/(.*)\"(.*?)$|\1file: \"~/${destinationrelativepath}/\2\"\3|g" "${composefile}"
        sed -Ei "s|^(\s*)file:\s*?\"${originabsolutepath}/(.*)\"(.*?)$|\1file: \"${destinationabsolutepath}/\2\"\3|g" "${composefile}"

   done
done

# Reset podman as user
generic_cmd "${user}" "podman" "system" "reset"

# Remove remaining stuff in storage and images
rm -rf ${sourcedir}/storage/*
rm -rf ${sourcedir}/images/*
rm -rf ${destinationdir}/storage/*
rm -rf ${destinationdir}/images/*

# Regenerate Entries
systemd_reload "${user}"

# Shoud Reboot
echo "You should now Reboot !"
