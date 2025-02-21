#!/bin/bash

# Define Root Data Folder
DATA_FOLDER="$1"

# If not set, ask user Interactively
while [ -z "${DATA_FOLDER}" ] || [ ! -d "${DATA_FOLDER}" ]
do
    # Ask User Interactively
    read -p "Enter Data Folder Root Path: " DATA_FOLDER
    echo -e ""
done

# Define Folders to be Created
FOLDERS=()
FOLDERS+=("pg_notify")
FOLDERS+=("pg_tblspc")
FOLDERS+=("pg_replslot")
FOLDERS+=("pg_twophase")
FOLDERS+=("pg_snapshots")
FOLDERS+=("pg_logical/snapshots")
FOLDERS+=("pg_logical/mappings")
FOLDERS+=("pg_commit_ts")
#FOLDERS+=("")

# Create Folder Structure
for FOLDER in "${FOLDERS[@]}"
do
    # Allow User to create Folders in SUBUID-owned Locations
    podman unshare mkdir -p "${DATA_FOLDER}/${FOLDER}"
done
